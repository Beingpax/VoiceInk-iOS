//
//  GroqTranscriptionService.swift
//

import Foundation

struct GroqTranscriptionResponse: Decodable {
    let text: String?
}

protocol TranscriptionService {
    func transcribeAudioFile(apiBaseURL: URL, apiKey: String, model: String, fileURL: URL, language: String?) async throws -> String
    func verifyAPIKey(apiBaseURL: URL, _ apiKey: String) async -> Bool
}

struct GroqTranscriptionService: TranscriptionService {
    // OpenAI-compatible APIs. Caller supplies baseURL and model.

    func transcribeAudioFile(apiBaseURL: URL, apiKey: String, model: String, fileURL: URL, language: String? = nil) async throws -> String {
        let components = URLComponents(url: apiBaseURL.appendingPathComponent("/v1/audio/transcriptions"), resolvingAgainstBaseURL: false)!
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()

        func appendFormField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // model field
        appendFormField("model", model)
        if let language {
            appendFormField("language", language)
        }

        // file field
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GroqAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        // Some OpenAI-compatible APIs return JSON with a text property; others return nested objects.
        // Try to parse a simple text response first, else fallback to raw string.
        if let decoded = try? JSONDecoder().decode(GroqTranscriptionResponse.self, from: data), let t = decoded.text {
            return t
        }
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }

    func verifyAPIKey(apiBaseURL: URL, _ apiKey: String) async -> Bool {
        // Hit a lightweight endpoint (models listing) to verify
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("/v1/models"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}


