import Foundation
import os

class VADModelManager {
    static let shared = VADModelManager()
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "VADModelManager")
    private var modelPath: String?

    private init() {
        if let path = Bundle.main.path(forResource: "ggml-silero-v5.1.2", ofType: "bin") {
            self.modelPath = path
            logger.info("VAD model found at path: \(path)")
        } else {
            logger.error("VAD model 'ggml-silero-v5.1.2.bin' not found in bundle resources.")
        }
    }

    func getModelPath() -> String? {
        return modelPath
    }
}
