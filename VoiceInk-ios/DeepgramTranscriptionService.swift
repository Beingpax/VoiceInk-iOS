//
//  DeepgramTranscriptionService.swift
//

import Foundation

struct DeepgramTranscriptionResponse: Decodable {
    let results: DeepgramResults
}

struct DeepgramResults: Decodable {
    let channels: [DeepgramChannel]
}

struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Decodable {
    let transcript: String
}

struct DeepgramTranscriptionService: TranscriptionService {
    
    func transcribeAudioFile(apiBaseURL: URL, apiKey: String, model: String, fileURL: URL, language: String? = nil) async throws -> String {
        // Build query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "diarize", value: "false")
        ]
        
        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("/v1/listen"), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        
        // Read audio file data
        let audioData = try Data(contentsOf: fileURL)
        request.httpBody = audioData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        guard (200..<300).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "DeepgramAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
        
        let decoded = try JSONDecoder().decode(DeepgramTranscriptionResponse.self, from: data)
        return decoded.results.channels.first?.alternatives.first?.transcript ?? ""
    }
    
    func verifyAPIKey(apiBaseURL: URL, _ apiKey: String) async -> Bool {
        // Use the projects endpoint to verify the API key
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("/v1/projects"))
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}