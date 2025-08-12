import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var openAICompatibleAPIKey: String {
        didSet { UserDefaults.standard.set(openAICompatibleAPIKey, forKey: "openAICompatibleAPIKey") }
    }

    @Published var preferredModel: String {
        didSet { UserDefaults.standard.set(preferredModel, forKey: "preferredModel") }
    }

    private init() {
        self.openAICompatibleAPIKey = UserDefaults.standard.string(forKey: "openAICompatibleAPIKey") ?? ""
        self.preferredModel = UserDefaults.standard.string(forKey: "preferredModel") ?? "whisper-large-v3"
    }
}


