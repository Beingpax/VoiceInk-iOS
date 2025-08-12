import Foundation

struct OAChatMessage: Codable { let role: String; let content: String }
struct OAChatRequest: Codable { let model: String; let messages: [OAChatMessage]; let temperature: Double? }
struct OAChatChoice: Codable { let message: OAChatMessage }
struct OAChatResponse: Codable { let choices: [OAChatChoice] }

struct OpenAICompatibleClient {
    func verifyAPIKey(baseURL: URL, apiKey: String) async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/models"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch { return false }
    }

    func chatCompletion(baseURL: URL, apiKey: String, model: String, messages: [OAChatMessage], temperature: Double? = 0.2) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = OAChatRequest(model: model, messages: messages, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "OAChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        let decoded = try JSONDecoder().decode(OAChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }
}


