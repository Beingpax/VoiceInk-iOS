import Foundation

struct ChatMessage: Encodable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
}

struct ChatChoice: Decodable { let message: ChatMessageResponse }
struct ChatMessageResponse: Decodable { let role: String; let content: String }
struct ChatResponse: Decodable { let choices: [ChatChoice] }

enum LLMPostProcessorError: Error { case invalidResponse }

struct LLMPostProcessor {
    func postProcessTranscript(provider: Provider, apiKey: String, model: String, prompt: String, transcript: String) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return transcript }

        let url = provider.baseURL.appendingPathComponent("/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = "You are a helpful assistant that rewrites raw speech-to-text transcripts to be concise, well-punctuated, and readable notes, preserving meaning."
        let contentPrompt = "Prompt: \(prompt)\n\nTranscript:\n\(transcript)"
        let payload = ChatRequest(model: model, messages: [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: contentPrompt)
        ], temperature: 0.2)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMPostProcessorError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? transcript
    }
}


