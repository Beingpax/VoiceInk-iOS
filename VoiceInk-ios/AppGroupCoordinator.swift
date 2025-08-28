import Foundation

/// Handles communication between the main VoiceInk app and the keyboard extension
/// Uses App Groups + Darwin Notifications for reliable iOS-native communication
final class AppGroupCoordinator {
    static let shared = AppGroupCoordinator()
    
    // MARK: - Constants
    private let appGroupIdentifier = "group.com.prakashjoshipax.VoiceInk"
    
    // UserDefaults keys for persistent state
    private enum UserDefaultsKeys {
        static let shouldStartRecording = "shouldStartRecording"
        static let shouldStopRecording = "shouldStopRecording"
        static let isRecording = "isRecording"
        static let lastRecordingTimestamp = "lastRecordingTimestamp"
    }
    
    // Darwin notification names for real-time communication
    private enum NotificationNames {
        static let startRecording = "com.prakashjoshipax.VoiceInk.startRecording"
        static let stopRecording = "com.prakashjoshipax.VoiceInk.stopRecording"
        static let recordingStateChanged = "com.prakashjoshipax.VoiceInk.recordingStateChanged"
    }
    
    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    
    // Callbacks for the main app
    var onStartRecordingRequested: (() -> Void)?
    var onStopRecordingRequested: (() -> Void)?
    
    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        setupNotificationObservers()
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - Public Interface for Keyboard Extension
    
    /// Call this from the keyboard extension to request recording start
    func requestStartRecording() {
        let timestamp = Date().timeIntervalSince1970
        
        // Set persistent flag
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldStartRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        
        // Send immediate notification
        postDarwinNotification(NotificationNames.startRecording)
    }
    
    /// Call this from the keyboard extension to request recording stop
    func requestStopRecording() {
        let timestamp = Date().timeIntervalSince1970
        
        // Set persistent flag
        sharedDefaults?.set(true, forKey: UserDefaultsKeys.shouldStopRecording)
        sharedDefaults?.set(timestamp, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        
        // Send immediate notification
        postDarwinNotification(NotificationNames.stopRecording)
    }
    
    /// Get current recording state (for keyboard UI updates)
    var isRecording: Bool {
        let storedState = sharedDefaults?.bool(forKey: UserDefaultsKeys.isRecording) ?? false
        let timestamp = sharedDefaults?.double(forKey: UserDefaultsKeys.lastRecordingTimestamp) ?? 0
        let currentTime = Date().timeIntervalSince1970
        
        // If the stored state is more than 30 seconds old, consider it stale
        if storedState && (currentTime - timestamp) > 30 {
            print("⚠️ Recording state appears stale, clearing it")
            updateRecordingState(false)
            return false
        }
        
        return storedState
    }
    
    // MARK: - Public Interface for Main App
    
    /// Call this from the main app to update recording state
    func updateRecordingState(_ isRecording: Bool) {
        sharedDefaults?.set(isRecording, forKey: UserDefaultsKeys.isRecording)
        // Update timestamp whenever state changes
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastRecordingTimestamp)
        
        // Notify keyboard of state change
        postDarwinNotification(NotificationNames.recordingStateChanged)
        
        print("📡 Updated recording state: \(isRecording)")
    }
    
    /// Check and consume start recording flag (returns true if should start)
    func checkAndConsumeStartRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }
        
        let shouldStart = defaults.bool(forKey: UserDefaultsKeys.shouldStartRecording)
        if shouldStart {
            // Consume the flag
            defaults.set(false, forKey: UserDefaultsKeys.shouldStartRecording)
            return true
        }
        return false
    }
    
    /// Check and consume stop recording flag (returns true if should stop)
    func checkAndConsumeStopRecordingFlag() -> Bool {
        guard let defaults = sharedDefaults else { return false }
        
        let shouldStop = defaults.bool(forKey: UserDefaultsKeys.shouldStopRecording)
        if shouldStop {
            // Consume the flag
            defaults.set(false, forKey: UserDefaultsKeys.shouldStopRecording)
            return true
        }
        return false
    }
    
    // MARK: - Darwin Notifications (Real-time Communication)
    
    private func setupNotificationObservers() {
        guard let center = notificationCenter else { return }
        
        // Observe start recording notifications
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleStartRecordingNotification()
            },
            NotificationNames.startRecording as CFString,
            nil,
            .deliverImmediately
        )
        
        // Observe stop recording notifications
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<AppGroupCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleStopRecordingNotification()
            },
            NotificationNames.stopRecording as CFString,
            nil,
            .deliverImmediately
        )
    }
    
    private func removeNotificationObservers() {
        guard let center = notificationCenter else { return }
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private func postDarwinNotification(_ name: String) {
        guard let center = notificationCenter else { return }
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
    
    // MARK: - Notification Handlers
    
    private func handleStartRecordingNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.onStartRecordingRequested?()
        }
    }
    
    private func handleStopRecordingNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.onStopRecordingRequested?()
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Clear all shared data (useful for debugging)
    func clearAllSharedData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: UserDefaultsKeys.shouldStartRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.shouldStopRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.isRecording)
        defaults.removeObject(forKey: UserDefaultsKeys.lastRecordingTimestamp)
    }
    
    /// Get debug info about current state
    func getDebugInfo() -> [String: Any] {
        guard let defaults = sharedDefaults else { return ["error": "No shared defaults"] }
        
        return [
            "shouldStartRecording": defaults.bool(forKey: UserDefaultsKeys.shouldStartRecording),
            "shouldStopRecording": defaults.bool(forKey: UserDefaultsKeys.shouldStopRecording),
            "isRecording": defaults.bool(forKey: UserDefaultsKeys.isRecording),
            "lastRecordingTimestamp": defaults.double(forKey: UserDefaultsKeys.lastRecordingTimestamp),
            "appGroupIdentifier": appGroupIdentifier
        ]
    }
}
