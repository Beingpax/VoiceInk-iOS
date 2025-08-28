# Integrating Keyboard Kit with VoiceInk for Recording

This document outlines the steps to integrate Keyboard Kit into the VoiceInk application to allow users to trigger a recording in the main app directly from the keyboard.

## Phase 1: Project Setup and Configuration

- [x] **Create an App Group for Data Sharing:**
    - In Xcode, open your project settings by selecting the `VoiceInk-ios` project in the Project Navigator.
    - Go to the `Signing & Capabilities` tab for the `VoiceInk-ios` target.
    - Click the `+ Capability` button and add `App Groups`.
    - In the App Groups section, click the `+` button to create a new group. The name should be something like `group.com.yourcompany.voiceink`. Make sure to note this name down.

- [x] **Create a New Keyboard Extension Target:**
    - In Xcode, go to `File` > `New` > `Target...`.
    - Select `Custom Keyboard Extension` from the `iOS` tab and click `Next`.
    - Give your extension a name (e.g., `VoiceInkKeyboard`) and make sure the `Project` and `Embed in Application` are set to your main app.
    - Click `Finish`. Xcode will ask if you want to activate the new scheme; click `Activate`.

- [x] **Configure the Keyboard Extension:**
    - A new folder for your keyboard extension will be created. Select the new target (e.g., `VoiceInkKeyboard`).
    - Go to its `Signing & Capabilities` tab.
    - Add the `App Groups` capability, just like you did for the main app.
    - Select the same App Group you created earlier.

- [x] **Add Keyboard Kit Dependency:**
    - Go to `File` > `Add Packages...`.
    - In the search bar, paste this URL: `https://github.com/KeyboardKit/KeyboardKit.git`.
    - Select the `KeyboardKit` package, and for the `Add to Target` dropdown, make sure you select your new keyboard extension target (`VoiceInkKeyboard`).
    - Click `Add Package`.

## Phase 2: Building the Keyboard and Communication

- [ ] **Request Full Access for the Keyboard:**
    - In the project navigator, find the `Info.plist` file inside your keyboard extension's folder.
    - Right-click and choose `Open As` > `Source Code`.
    - Inside the `NSExtension` dictionary, add the following key-value pair to request open access, which is necessary for the keyboard to interact with the App Group.
        ```xml
        <key>RequestsOpenAccess</key>
        <true/>
        ```
- [ ] **Design the Keyboard with a Record Button:**
    - In `KeyboardViewController.swift`, use Keyboard Kit to create a custom layout that includes a "Record" button.

- [ ] **Implement Keyboard-to-App Signaling:**
    - Create a new Swift file, `AppGroupCoordinator.swift`, to manage communication.
    - In this file, create a class or struct to handle:
        1. Writing a "start recording" signal to a shared `UserDefaults` instance associated with your App Group.
        2. Posting Darwin notifications for immediate communication between keyboard and main app.
    - Make sure to add this new file to both the main app target and the keyboard extension target in the "Target Membership" inspector.
    - When the user taps the Record button, the keyboard will:
        1. Set a flag (e.g., `shouldStartRecording = true`) in the shared `UserDefaults`.
        2. Post a Darwin notification (e.g., `com.yourcompany.voiceink.startRecording`) to immediately notify the main app.

## Phase 3: Implementing Recording in the Main App

- [ ] **Listen for Signals in the Main App:**
    - In your main app, likely within your `RecordingManager` or a similar central class, use the `AppGroupCoordinator` to:
        1. Register a Darwin notification observer for the recording signals (e.g., `com.yourcompany.voiceink.startRecording`).
        2. When a Darwin notification is received, immediately check the corresponding flag in the shared `UserDefaults`.
    - This approach provides immediate notification when the keyboard sends a signal, eliminating the need for polling or timers.

- [ ] **Handle Recording Lifecycle:**
    - When the main app detects that `shouldStartRecording` is `true`, it will:
        1. Immediately reset the flag to `false` in shared `UserDefaults` to prevent multiple recordings.
        2. Start the audio recording using your existing `AudioRecorder` service.
    - You will need a corresponding "Stop" button in the keyboard that:
        1. Sets a `shouldStopRecording` flag in shared `UserDefaults`.
        2. Posts a Darwin notification (e.g., `com.yourcompany.voiceink.stopRecording`) to immediately notify the main app to stop and save the recording.

- [ ] **Provide User Feedback:**
    - The keyboard UI should update to indicate that a recording is in progress (e.g., the record button changes to a stop icon). This state can also be managed via a flag in the shared `UserDefaults` (e.g., `isRecording`). The keyboard will read this flag to update its UI.
