import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case ai = "AI Engine"
    case voice = "Voice"
    case screen = "Screen"
    case agent = "Agent"
    case privacy = "Privacy"
    case developer = "Developer"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .ai: return "cpu"
        case .voice: return "mic"
        case .screen: return "macwindow.on.rectangle"
        case .agent: return "bolt"
        case .privacy: return "hand.raised"
        case .developer: return "hammer"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager = .shared
    @ObservedObject var privacy: PrivacyManager = .shared
    @ObservedObject var permissions: PermissionManager = .shared
    @State private var selectedTab: SettingsTab = .general
    
    // API Key input temporary state
    @State private var apiKeyInput: String = ""
    @State private var isKeySaved: Bool = false
    @State private var saveStatusMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    RioSparkleView(size: 13)
                    Text("Rio Preferences")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
                Button("Done") {
                    AppState.shared.isSettingsOpen = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }
                    .tag(SettingsTab.general)
                
                aiTab
                    .tabItem { Label("AI Engine", systemImage: "cpu") }
                    .tag(SettingsTab.ai)
                
                voiceTab
                    .tabItem { Label("Voice", systemImage: "mic") }
                    .tag(SettingsTab.voice)
                
                screenTab
                    .tabItem { Label("Screen", systemImage: "macwindow.on.rectangle") }
                    .tag(SettingsTab.screen)
                
                agentTab
                    .tabItem { Label("Agent", systemImage: "bolt") }
                    .tag(SettingsTab.agent)
                
                privacyTab
                    .tabItem { Label("Privacy", systemImage: "hand.raised") }
                    .tag(SettingsTab.privacy)
                
                developerTab
                    .tabItem { Label("Developer", systemImage: "hammer") }
                    .tag(SettingsTab.developer)
            }
        }
        .frame(width: 540, height: 460)
        .padding(.bottom, 10)
        .onAppear {
            refreshKeyStatus()
        }
    }
    
    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section(header: Text("Application Behavior")) {
                Toggle("Launch REO at login", isOn: $settings.launchAtLogin)
                Toggle("Start minimized in menu bar", isOn: $settings.startMinimized)
            }
            
            Section(header: Text("Global Activation Shortcut")) {
                HStack {
                    Text("Activation Hotkey:")
                    Spacer()
                    Text(settings.globalShortcut)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                Text("Default is Command + Shift + Space. Focuses and opens REO from anywhere in macOS.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Appearance")) {
                Picker("Theme:", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - AI Tab
    private var aiTab: some View {
        Form {
            Section(header: Text("AI Provider Selection")) {
                Picker("Active Provider:", selection: $settings.aiProvider) {
                    ForEach(AIProviderType.allCases) { prov in
                        Text(prov.rawValue).tag(prov)
                    }
                }
                .onChange(of: settings.aiProvider) { _, newProvider in
                    settings.modelName = newProvider.defaultModel
                    refreshKeyStatus()
                    AppState.shared.updateActiveAIProvider()
                }
                
                TextField("Model Identifier:", text: $settings.modelName)
                
                if settings.aiProvider != .mock {
                    TextField("Base URL (optional):", text: $settings.customBaseURL, prompt: Text(settings.aiProvider.defaultBaseURL))
                }
            }
            
            if settings.aiProvider != .mock && settings.aiProvider != .ollama {
                Section(header: Text("Secure Keychain Credentials")) {
                    HStack {
                        SecureField("API Key:", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Save Key") {
                            saveAPIKey()
                        }
                        
                        if isKeySaved {
                            Button("Delete", role: .destructive) {
                                deleteAPIKey()
                            }
                        }
                    }
                    
                    HStack {
                        Text(isKeySaved ? "✓ Key securely stored in macOS Keychain" : "No key stored for this provider.")
                            .font(.caption)
                            .foregroundColor(isKeySaved ? .green : .secondary)
                        Spacer()
                    }
                    
                    if let msg = saveStatusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("Inference Parameters")) {
                Slider(value: $settings.temperature, in: 0.0...1.0, step: 0.05) {
                    Text("Temperature: \(settings.temperature, specifier: "%.2f")")
                }
                Toggle("Enable response streaming", isOn: $settings.streamingEnabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom System Instructions:")
                        .font(.caption)
                    TextEditor(text: $settings.customSystemInstructions)
                        .frame(height: 60)
                        .font(.system(size: 11))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Voice Tab
    private var voiceTab: some View {
        Form {
            Section(header: Text("Speech Output (Text-to-Speech)")) {
                Toggle("Enable spoken responses", isOn: $settings.enableSpokenResponses)
                Slider(value: $settings.speechRate, in: 0.2...0.8, step: 0.05) {
                    Text("Speech Rate: \(settings.speechRate, specifier: "%.2f")")
                }
                
                Button("Test Voice Synthesis") {
                    TextToSpeech.shared.speak(text: "Hello! I am REO, your personal computer assistant.")
                }
            }
            
            Section(header: Text("Microphone & Dictation")) {
                Toggle("Push-to-talk mode", isOn: $settings.pushToTalk)
                
                HStack {
                    Text("Microphone Permission:")
                    Spacer()
                    Text(permissions.microphoneStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(permissions.microphoneStatus == .granted ? .green : .orange)
                    if permissions.microphoneStatus != .granted {
                        Button("Open Settings") {
                            permissions.openSettings(for: .microphone)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                
                HStack {
                    Text("Speech Recognition:")
                    Spacer()
                    Text(permissions.speechRecognitionStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(permissions.speechRecognitionStatus == .granted ? .green : .orange)
                    if permissions.speechRecognitionStatus != .granted {
                        Button("Open Settings") {
                            permissions.openSettings(for: .speechRecognition)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Screen Tab
    private var screenTab: some View {
        Form {
            Section(header: Text("Screen Awareness")) {
                Toggle("Enable screen awareness capabilities", isOn: $settings.screenAwarenessEnabled)
                
                Picker("Capture Target:", selection: $settings.screenCaptureMode) {
                    ForEach(ScreenCaptureMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                HStack {
                    Text("Screen Recording Permission:")
                    Spacer()
                    Text(permissions.screenRecordingStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(permissions.screenRecordingStatus == .granted ? .green : .orange)
                }
                
                Text("REO only captures visual context when you explicitly prompt 'look at my screen'. Screen context is automatically cleared after response.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Agent Tab
    private var agentTab: some View {
        Form {
            Section(header: Text("Action Confirmation Levels")) {
                Toggle("Require confirmation for Low-Risk actions (e.g. open URL, switch app)", isOn: $settings.confirmLowRiskActions)
                Toggle("Require confirmation for Medium-Risk actions (e.g. type text, create file)", isOn: $settings.confirmMediumRiskActions)
                Toggle("Always confirm High-Risk actions (e.g. terminal commands, deletion)", isOn: $settings.alwaysConfirmHighRiskActions)
                    .disabled(true) // Always enforced
            }
            
            Section(header: Text("Action History")) {
                HStack {
                    Text("\(ActionHistory.shared.entries.count) actions recorded this session.")
                        .font(.caption)
                    Spacer()
                    Button("Clear History") {
                        ActionHistory.shared.clearHistory()
                    }
                }
            }
        }
    }
    
    // MARK: - Privacy Tab
    private var privacyTab: some View {
        Form {
            Section(header: Text("Privacy Mode")) {
                Toggle("Enable Strict Privacy Mode", isOn: $settings.privacyMode)
                    .onChange(of: settings.privacyMode) { _, active in
                        privacy.togglePrivacyMode(active)
                    }
                
                Text("When active: visual context is aggressively discarded, logs are restricted, and confirmation is required for all computer actions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Conversation Retention")) {
                Picker("Retention Policy:", selection: $settings.conversationRetention) {
                    ForEach(ConversationRetention.allCases) { ret in
                        Text(ret.rawValue).tag(ret)
                    }
                }
                
                Button("Purge All Local Data & Reset", role: .destructive) {
                    privacy.clearAllLocalData()
                    ConversationEngine.shared.clearConversation()
                }
            }
        }
    }
    
    // MARK: - Developer Tab
    private var developerTab: some View {
        Form {
            Section(header: Text("Diagnostics & Debug Mode")) {
                Toggle("Enable Developer Debug Logging", isOn: $settings.developerMode)
                
                HStack {
                    Text("Accessibility API:")
                    Spacer()
                    Text(permissions.accessibilityStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(permissions.accessibilityStatus == .granted ? .green : .orange)
                }
                
                HStack {
                    Text("Active AI Provider:")
                    Spacer()
                    Text(settings.aiProvider.rawValue)
                        .font(.caption)
                }
                
                HStack {
                    Text("Model:")
                    Spacer()
                    Text(settings.modelName)
                        .font(.caption)
                }
            }
        }
    }
    
    private func refreshKeyStatus() {
        isKeySaved = SecureStorage.shared.hasAPIKey(for: settings.aiProvider)
        apiKeyInput = ""
        saveStatusMessage = nil
    }
    
    private func saveAPIKey() {
        do {
            try SecureStorage.shared.saveAPIKey(apiKeyInput, for: settings.aiProvider)
            isKeySaved = true
            apiKeyInput = ""
            saveStatusMessage = "Key saved securely to Keychain."
        } catch {
            saveStatusMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func deleteAPIKey() {
        do {
            try SecureStorage.shared.deleteAPIKey(for: settings.aiProvider)
            isKeySaved = false
            saveStatusMessage = "Key removed from Keychain."
        } catch {
            saveStatusMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}
