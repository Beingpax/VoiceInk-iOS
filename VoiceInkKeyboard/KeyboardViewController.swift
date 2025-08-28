//
//  KeyboardViewController.swift
//  VoiceInkKeyboard
//
//  Created by Prakash Joshi on 28/08/2025.
//

import UIKit
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {
    
    var recordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
    }
    
    private func setupKeyboard() {
        // Setup KeyboardKit with default configuration
        setupKeyboardKit()
        
        // Add our custom record button at the top
        setupRecordButton()
    }
    
    private func setupKeyboardKit() {
        // KeyboardInputViewController automatically sets up the keyboard
        // We can customize the keyboard appearance here if needed
        
        // Make the keyboard more compact
        setupCompactKeyboard()
    }
    
    private func setupCompactKeyboard() {
        // Customize KeyboardKit's key styling to make keys more compact
        // This requires working with KeyboardKit's styling system
        
        // Note: KeyboardKit's styling is complex and may require KeyboardKit Pro
        // For now, we'll keep the default keyboard layout
        // Individual key customization would require:
        // 1. Custom KeyboardStyleProvider
        // 2. Custom KeyboardLayoutProvider  
        // 3. Overriding key button styles
        
    }
    
    private func setupRecordButton() {
        // Create the capsule-shaped record button
        recordButton = UIButton(type: .system)
        recordButton.setTitle("🎤 Record", for: .normal)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        recordButton.backgroundColor = UIColor.systemRed
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.layer.cornerRadius = 14 // Will be adjusted to make it capsule-shaped
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        // Add some padding and styling for better appearance
        recordButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        recordButton.layer.shadowColor = UIColor.black.cgColor
        recordButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        recordButton.layer.shadowOpacity = 0.15
        recordButton.layer.shadowRadius = 1.5
        
        // Add button to main view
        view.addSubview(recordButton)
        
        // Set up constraints - position in top center with safe margins
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            recordButton.heightAnchor.constraint(equalToConstant: 28),
            recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        // Ensure button stays on top
        view.bringSubviewToFront(recordButton)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Re-add and ensure record button stays on top after KeyboardKit layout
        if let button = recordButton {
            if button.superview == nil {
                view.addSubview(button)
            }
            view.bringSubviewToFront(button)
            
            // Ensure proper capsule shape after layout
            DispatchQueue.main.async {
                button.layer.cornerRadius = button.frame.height / 2
            }
        } else {
            // no-op
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Re-add button if KeyboardKit removed it
        if let button = recordButton, button.superview == nil {
            view.addSubview(button)
        }
        
        // Ensure button is still visible after layout
        if let button = recordButton {
            view.bringSubviewToFront(button)
            
            // Make button fully capsule-shaped based on its actual height
            button.layer.cornerRadius = button.frame.height / 2
        }
    }
    
    @objc private func recordButtonTapped() {
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Simply open the main app for recording
        // No more complex coordination - just switch to main app
        openMainAppForRecording()
    }
    
    private func openMainAppForRecording() {
        // iOS keyboard extensions have severe limitations with audio recording
        // The correct approach is to simply open the main app and let user record there
        
        // Try multiple approaches to open the main app
        if let url = URL(string: "voiceink://record") {
            // Method 1: Try extensionContext.open (primary method)
            extensionContext?.open(url) { success in
                if success {
                    print("✅ Opened main app via extensionContext")
                } else {
                    print("❌ extensionContext.open failed, trying alternative methods")
                    DispatchQueue.main.async {
                        self.tryAlternativeURLOpening(url)
                    }
                }
            }
        } else {
            // Fallback: Show message to user
            showUserMessage()
        }
    }
    
    private func tryAlternativeURLOpening(_ url: URL) {
        // Try UIApplication directly if available
        if let sharedApp = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
            if sharedApp.canOpenURL(url) {
                sharedApp.open(url, options: [:]) { success in
                    if success {
                        print("✅ Opened main app via UIApplication.open")
                    } else {
                        print("❌ UIApplication.open failed")
                        self.showUserMessage()
                    }
                }
                return
            }
        }
        
        // Fallback: Try responder chain method
        openURLViaResponderChain(url)
    }
    
    private func openURLViaResponderChain(_ url: URL) {
        // iOS 18 workaround: Use responder chain to open URL
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        
        while let r = responder, !r.responds(to: selector) {
            responder = r.next
        }
        
        if let responder = responder {
            _ = responder.perform(selector, with: url)
            print("✅ Attempted to open main app via responder chain")
            // Don't assume success since we can't get feedback from this method
        } else {
            print("❌ All URL opening methods failed")
            showUserMessage()
        }
    }
    
    private func showUserMessage() {
        // Last resort: Update button to show user should open main app manually
        recordButton.setTitle("📱 Open VoiceInk", for: .normal)
        recordButton.backgroundColor = UIColor.systemBlue
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.recordButton.setTitle("🎤 Record", for: .normal)
            self.recordButton.backgroundColor = UIColor.systemRed
        }
    }
    
    private func updateButtonAppearanceBasedOnState() {
        // Simplified: Always show "Record" since we just open the main app
        recordButton.backgroundColor = UIColor.systemRed
        recordButton.setTitle("🎤 Record", for: .normal)
        
        // Ensure capsule shape is maintained
        recordButton.layer.cornerRadius = recordButton.frame.height / 2
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents
        super.textWillChange(textInput)
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents
        super.textDidChange(textInput)
    }
}
