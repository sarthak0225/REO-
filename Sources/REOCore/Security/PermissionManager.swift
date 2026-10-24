import Foundation
import AppKit
import AVFoundation
import Speech
import ApplicationServices

public enum PermissionType: String, CaseIterable, Identifiable, Sendable {
    case accessibility = "Accessibility"
    case screenRecording = "Screen Recording"
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    
    public var id: String { rawValue }
    
    public var descriptionText: String {
        switch self {
        case .accessibility:
            return "Allows REO to interact with apps, type text, and execute computer actions on your behalf."
        case .screenRecording:
            return "Allows REO to inspect visual context when you explicitly ask 'What's on my screen?'"
        case .microphone:
            return "Allows you to speak to REO using voice input and push-to-talk."
        case .speechRecognition:
            return "Enables fast, on-device transcription of your voice commands."
        }
    }
    
    public var settingsURL: URL? {
        switch self {
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        }
    }
}

public enum PermissionStatus: String, Sendable {
    case granted = "Granted"
    case denied = "Denied"
    case notDetermined = "Not Determined"
    case restricted = "Restricted"
}

@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    @Published public private(set) var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published public private(set) var microphoneStatus: PermissionStatus = .notDetermined
    @Published public private(set) var speechRecognitionStatus: PermissionStatus = .notDetermined
    
    private init() {
        checkAllPermissions()
    }
    
    public func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .accessibility: return accessibilityStatus
        case .screenRecording: return screenRecordingStatus
        case .microphone: return microphoneStatus
        case .speechRecognition: return speechRecognitionStatus
        }
    }
    
    public func checkAllPermissions() {
        checkAccessibility()
        checkScreenRecording()
        checkMicrophone()
        checkSpeechRecognition()
    }
    
    // MARK: - Accessibility
    public func checkAccessibility() {
        let isTrusted = AXIsProcessTrusted()
        accessibilityStatus = isTrusted ? .granted : .denied
    }
    
    public func requestAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        checkAccessibility()
    }
    
    // MARK: - Screen Recording
    public func checkScreenRecording() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .granted : .denied
    }
    
    public func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        checkScreenRecording()
    }
    
    // MARK: - Microphone
    public func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .denied:
            microphoneStatus = .denied
        case .restricted:
            microphoneStatus = .restricted
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .denied
        }
    }
    
    public func requestMicrophone() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            checkMicrophone()
            return true
        }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        checkMicrophone()
        return granted
    }
    
    // MARK: - Speech Recognition
    public func checkSpeechRecognition() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionStatus = .granted
        case .denied:
            speechRecognitionStatus = .denied
        case .restricted:
            speechRecognitionStatus = .restricted
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        @unknown default:
            speechRecognitionStatus = .denied
        }
    }
    
    public func requestSpeechRecognition() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized {
            self.checkSpeechRecognition()
            return true
        }
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        self.checkSpeechRecognition()
        return authStatus == .authorized
    }
    
    // MARK: - Open System Settings
    public func openSettings(for type: PermissionType) {
        if let url = type.settingsURL {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallback)
        }
    }
}
