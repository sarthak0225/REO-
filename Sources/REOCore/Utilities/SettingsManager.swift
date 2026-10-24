import Foundation
import SwiftUI

public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"
    
    public var id: String { rawValue }
}

public enum AIProviderType: String, CaseIterable, Identifiable, Sendable {
    case mock = "Mock / Offline"
    case openAI = "OpenAI Compatible"
    case anthropic = "Anthropic Claude"
    case gemini = "Google Gemini"
    case ollama = "Local Ollama"
    case custom = "Custom Backend"
    
    public var id: String { rawValue }
    
    public var defaultModel: String {
        switch self {
        case .mock: return "mock-reo-v1"
        case .openAI: return "gpt-4o"
        case .anthropic: return "claude-3-7-sonnet"
        case .gemini: return "gemini-flash-latest"
        case .ollama: return "llama3"
        case .custom: return "default"
        }
    }
    
    public var defaultBaseURL: String {
        switch self {
        case .mock: return ""
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .ollama: return "http://localhost:11434"
        case .custom: return "https://api.example.com/v1"
        }
    }
}

public enum ScreenCaptureMode: String, CaseIterable, Identifiable, Sendable {
    case currentDisplay = "Current Display"
    case activeWindow = "Active Window"
    case allDisplays = "All Displays"
    
    public var id: String { rawValue }
}

public enum ConversationRetention: String, CaseIterable, Identifiable, Sendable {
    case sessionOnly = "Current Session Only"
    case ephemeral = "Immediate Deletion"
    case persistent = "Retain History"
    
    public var id: String { rawValue }
}

@MainActor
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - General
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "reo_launchAtLogin") }
    }
    @Published public var globalShortcut: String {
        didSet { defaults.set(globalShortcut, forKey: "reo_globalShortcut") }
    }
    @Published public var startMinimized: Bool {
        didSet { defaults.set(startMinimized, forKey: "reo_startMinimized") }
    }
    @Published public var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "reo_appearance") }
    }
    
    // MARK: - Voice
    @Published public var enableSpokenResponses: Bool {
        didSet { defaults.set(enableSpokenResponses, forKey: "reo_enableSpokenResponses") }
    }
    @Published public var speechRate: Float {
        didSet { defaults.set(speechRate, forKey: "reo_speechRate") }
    }
    @Published public var selectedVoiceIdentifier: String {
        didSet { defaults.set(selectedVoiceIdentifier, forKey: "reo_selectedVoiceIdentifier") }
    }
    @Published public var pushToTalk: Bool {
        didSet { defaults.set(pushToTalk, forKey: "reo_pushToTalk") }
    }
    
    // MARK: - AI
    @Published public var aiProvider: AIProviderType {
        didSet { defaults.set(aiProvider.rawValue, forKey: "reo_aiProvider") }
    }
    @Published public var modelName: String {
        didSet { defaults.set(modelName, forKey: "reo_modelName") }
    }
    @Published public var customBaseURL: String {
        didSet { defaults.set(customBaseURL, forKey: "reo_customBaseURL") }
    }
    @Published public var temperature: Double {
        didSet { defaults.set(temperature, forKey: "reo_temperature") }
    }
    @Published public var streamingEnabled: Bool {
        didSet { defaults.set(streamingEnabled, forKey: "reo_streamingEnabled") }
    }
    @Published public var customSystemInstructions: String {
        didSet { defaults.set(customSystemInstructions, forKey: "reo_customSystemInstructions") }
    }
    
    // MARK: - Screen
    @Published public var screenAwarenessEnabled: Bool {
        didSet { defaults.set(screenAwarenessEnabled, forKey: "reo_screenAwarenessEnabled") }
    }
    @Published public var screenCaptureMode: ScreenCaptureMode {
        didSet { defaults.set(screenCaptureMode.rawValue, forKey: "reo_screenCaptureMode") }
    }
    
    // MARK: - Agent & Safety
    @Published public var confirmLowRiskActions: Bool {
        didSet { defaults.set(confirmLowRiskActions, forKey: "reo_confirmLowRiskActions") }
    }
    @Published public var confirmMediumRiskActions: Bool {
        didSet { defaults.set(confirmMediumRiskActions, forKey: "reo_confirmMediumRiskActions") }
    }
    @Published public var alwaysConfirmHighRiskActions: Bool {
        didSet { defaults.set(alwaysConfirmHighRiskActions, forKey: "reo_alwaysConfirmHighRiskActions") }
    }
    
    // MARK: - Privacy
    @Published public var privacyMode: Bool {
        didSet {
            defaults.set(privacyMode, forKey: "reo_privacyMode")
            AppLogger.shared.isPrivacyModeActive = privacyMode
            EventBus.shared.publish(.privacyModeToggled(privacyMode))
        }
    }
    @Published public var conversationRetention: ConversationRetention {
        didSet { defaults.set(conversationRetention.rawValue, forKey: "reo_conversationRetention") }
    }
    
    // MARK: - Developer Mode
    @Published public var developerMode: Bool {
        didSet {
            defaults.set(developerMode, forKey: "reo_developerMode")
            AppLogger.shared.isDebugModeEnabled = developerMode
        }
    }
    
    private init() {
        // Defaults
        self.launchAtLogin = defaults.bool(forKey: "reo_launchAtLogin")
        self.globalShortcut = defaults.string(forKey: "reo_globalShortcut") ?? "⌘⇧Space"
        self.startMinimized = defaults.bool(forKey: "reo_startMinimized")
        
        if let rawApp = defaults.string(forKey: "reo_appearance"), let app = AppAppearance(rawValue: rawApp) {
            self.appearance = app
        } else {
            self.appearance = .system
        }
        
        self.enableSpokenResponses = defaults.object(forKey: "reo_enableSpokenResponses") != nil ? defaults.bool(forKey: "reo_enableSpokenResponses") : true
        self.speechRate = defaults.object(forKey: "reo_speechRate") != nil ? defaults.float(forKey: "reo_speechRate") : 0.5
        self.selectedVoiceIdentifier = defaults.string(forKey: "reo_selectedVoiceIdentifier") ?? ""
        self.pushToTalk = defaults.bool(forKey: "reo_pushToTalk")
        
        if let rawProvider = defaults.string(forKey: "reo_aiProvider"), let prov = AIProviderType(rawValue: rawProvider) {
            self.aiProvider = prov
        } else {
            self.aiProvider = .mock
        }
        
        self.modelName = defaults.string(forKey: "reo_modelName") ?? AIProviderType.mock.defaultModel
        self.customBaseURL = defaults.string(forKey: "reo_customBaseURL") ?? ""
        self.temperature = defaults.object(forKey: "reo_temperature") != nil ? defaults.double(forKey: "reo_temperature") : 0.7
        self.streamingEnabled = defaults.object(forKey: "reo_streamingEnabled") != nil ? defaults.bool(forKey: "reo_streamingEnabled") : true
        self.customSystemInstructions = defaults.string(forKey: "reo_customSystemInstructions") ?? ""
        
        self.screenAwarenessEnabled = defaults.object(forKey: "reo_screenAwarenessEnabled") != nil ? defaults.bool(forKey: "reo_screenAwarenessEnabled") : true
        if let rawMode = defaults.string(forKey: "reo_screenCaptureMode"), let mode = ScreenCaptureMode(rawValue: rawMode) {
            self.screenCaptureMode = mode
        } else {
            self.screenCaptureMode = .currentDisplay
        }
        
        self.confirmLowRiskActions = defaults.bool(forKey: "reo_confirmLowRiskActions") // Default: false (low risk can run automatically)
        self.confirmMediumRiskActions = defaults.object(forKey: "reo_confirmMediumRiskActions") != nil ? defaults.bool(forKey: "reo_confirmMediumRiskActions") : true
        self.alwaysConfirmHighRiskActions = defaults.object(forKey: "reo_alwaysConfirmHighRiskActions") != nil ? defaults.bool(forKey: "reo_alwaysConfirmHighRiskActions") : true
        
        let privMode = defaults.bool(forKey: "reo_privacyMode")
        self.privacyMode = privMode
        
        if let rawRetention = defaults.string(forKey: "reo_conversationRetention"), let ret = ConversationRetention(rawValue: rawRetention) {
            self.conversationRetention = ret
        } else {
            self.conversationRetention = .sessionOnly
        }
        
        let devMode = defaults.bool(forKey: "reo_developerMode")
        self.developerMode = devMode
        
        AppLogger.shared.isPrivacyModeActive = privMode
        AppLogger.shared.isDebugModeEnabled = devMode
    }
    
    public func resetToDefaults() {
        launchAtLogin = false
        globalShortcut = "⌘⇧Space"
        startMinimized = false
        appearance = .system
        enableSpokenResponses = true
        speechRate = 0.5
        selectedVoiceIdentifier = ""
        pushToTalk = false
        aiProvider = .mock
        modelName = AIProviderType.mock.defaultModel
        customBaseURL = ""
        temperature = 0.7
        streamingEnabled = true
        customSystemInstructions = ""
        screenAwarenessEnabled = true
        screenCaptureMode = .currentDisplay
        confirmLowRiskActions = false
        confirmMediumRiskActions = true
        alwaysConfirmHighRiskActions = true
        privacyMode = false
        conversationRetention = .sessionOnly
        developerMode = false
    }
}
