import Foundation

struct LLMPostProcessor {
    private let client = OpenAICompatibleClient()

    func postProcessTranscript(provider: Provider, apiKey: String, model: String, prompt: String, transcript: String) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return transcript }
        let systemPrompt = "You are a helpful assistant that rewrites raw speech-to-text transcripts to be concise, well-punctuated, and readable notes, preserving meaning."
        let contentPrompt = "Prompt: \(prompt)\n\nTranscript:\n\(transcript)"
        let messages = [
            OAChatMessage(role: "system", content: systemPrompt),
            OAChatMessage(role: "user", content: contentPrompt)
        ]
        
        let result = try await client.chatCompletion(baseURL: provider.baseURL, apiKey: apiKey, model: model, messages: messages, temperature: 0.2)
        return result.isEmpty ? transcript : result
    }
}


