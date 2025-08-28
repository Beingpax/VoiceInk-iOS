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
        
        // TODO: Use the coordinator to signal the main app
        // let coordinator = AppGroupCoordinator.shared
        
        // For now, just provide visual feedback
        updateButtonAppearanceBasedOnState()
    }
    
    private func updateButtonAppearanceBasedOnState() {
        // Temporary visual feedback until AppGroupCoordinator is implemented
        let isRecording = recordButton.backgroundColor == UIColor.systemGreen
        
        if isRecording {
            recordButton.backgroundColor = UIColor.systemRed
            recordButton.setTitle("🎤 Record", for: .normal)
        } else {
            recordButton.backgroundColor = UIColor.systemGreen
            recordButton.setTitle("⏹️ Stop", for: .normal)
        }
        
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
