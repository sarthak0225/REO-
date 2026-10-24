import Foundation
import SwiftUI
import Combine

public enum REOStatus: String, Sendable {
    case idle = "Ready"
    case listening = "Listening..."
    case thinking = "Thinking..."
    case speaking = "Speaking..."
    case capturing = "Capturing screen..."
    case executing = "Performing action..."
    case waitingForApproval = "Approval required"
    case completed = "Done"
    case error = "Attention needed"
    
    public var statusDotColor: Color {
        switch self {
        case .idle: return .green
        case .listening: return .blue
        case .thinking: return .purple
        case .speaking: return .cyan
        case .capturing: return .yellow
        case .executing: return .orange
        case .waitingForApproval: return .red
        case .completed: return .green
        case .error: return .red
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var status: REOStatus = .idle
    @Published public var statusMessage: String = "How can I help?"
    @Published public var inputText: String = ""
    @Published public var isPanelVisible: Bool = true
    @Published public var isExpanded: Bool = true
    @Published public var isQuickActionsOpen: Bool = false
    @Published public var isSettingsOpen: Bool = false
    @Published public var isPermissionViewOpen: Bool = false
    
    // Subsystem singletons
    public let settings = SettingsManager.shared
    public let privacy = PrivacyManager.shared
    public let permissions = PermissionManager.shared
    public let conversation = ConversationEngine.shared
    public let context = ContextManager.shared
    public let agent = AgentEngine.shared
    public let executor = ActionExecutor.shared
    public let planner = TaskPlanner.shared
    public let speech = SpeechRecognizer.shared
    public let tts = TextToSpeech.shared
    public let vision = ScreenCaptureManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        configureSubsystems()
        setupEventSubscriptions()
    }
    
    public func configureSubsystems() {
        if SecureStorage.shared.hasAPIKey(for: .gemini) {
            if settings.aiProvider == .mock {
                settings.aiProvider = .gemini
                settings.modelName = AIProviderType.gemini.defaultModel
                AppLogger.shared.info("Automatically activated Google Gemini provider from available credentials.", category: .ai)
            } else if settings.aiProvider == .gemini && (settings.modelName.isEmpty || settings.modelName.hasPrefix("gemini-1.5")) {
                settings.modelName = AIProviderType.gemini.defaultModel
            }
        }
        updateActiveAIProvider()
    }
    
    public func updateActiveAIProvider() {
        let providerType = settings.aiProvider
        let provider: AIProvider
        
        switch providerType {
        case .mock:
            provider = MockAIProvider()
        case .openAI:
            let baseURL = !settings.customBaseURL.isEmpty ? settings.customBaseURL : providerType.defaultBaseURL
            provider = OpenAICompatibleProvider(baseURL: baseURL)
        case .anthropic:
            let baseURL = !settings.customBaseURL.isEmpty ? settings.customBaseURL : providerType.defaultBaseURL
            provider = AnthropicProvider(baseURL: baseURL)
        case .gemini:
            let baseURL = !settings.customBaseURL.isEmpty ? settings.customBaseURL : providerType.defaultBaseURL
            provider = GeminiProvider(baseURL: baseURL)
        case .ollama:
            let baseURL = !settings.customBaseURL.isEmpty ? settings.customBaseURL : providerType.defaultBaseURL
            provider = OllamaProvider(baseURL: baseURL)
        case .custom:
            let baseURL = !settings.customBaseURL.isEmpty ? settings.customBaseURL : providerType.defaultBaseURL
            provider = OpenAICompatibleProvider(providerId: .custom, displayName: "Custom Backend", baseURL: baseURL)
        }
        
        conversation.setProvider(provider)
    }
    
    private func setupEventSubscriptions() {
        // Observe conversation engine processing state
        conversation.$isProcessing
            .sink { [weak self] processing in
                guard let self = self else { return }
                if processing {
                    self.setStatus(.thinking, message: "Reasoning & generating response...")
                } else if self.status == .thinking {
                    self.setStatus(.idle, message: "How can I help?")
                }
            }
            .store(in: &cancellables)
        
        // Observe speech listening state
        speech.$isListening
            .sink { [weak self] listening in
                guard let self = self else { return }
                if listening {
                    self.setStatus(.listening, message: "Listening to your voice...")
                } else if self.status == .listening {
                    self.setStatus(.idle, message: "How can I help?")
                }
            }
            .store(in: &cancellables)
        
        // Observe TTS speaking state
        tts.$isSpeaking
            .sink { [weak self] speaking in
                guard let self = self else { return }
                if speaking {
                    self.setStatus(.speaking, message: "Speaking response...")
                } else if self.status == .speaking {
                    self.setStatus(.idle, message: "How can I help?")
                }
            }
            .store(in: &cancellables)
        
        // Observe ActionExecutor pending approvals
        executor.$pendingAction
            .sink { [weak self] pending in
                guard let self = self else { return }
                if pending != nil {
                    self.setStatus(.waitingForApproval, message: "Action requires your approval")
                } else if self.status == .waitingForApproval {
                    self.setStatus(.idle, message: "How can I help?")
                }
            }
            .store(in: &cancellables)
    }
    
    public func setStatus(_ newStatus: REOStatus, message: String) {
        self.status = newStatus
        self.statusMessage = message
        EventBus.shared.publish(.assistantStateChanged(newStatus.rawValue))
    }
    
    // MARK: - User Input & Intent Handling
    public func submitCurrentInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || context.isScreenContextAttached else { return }
        
        expandPanel()
        inputText = ""
        handleUserInput(text)
    }
    
    public func toggleExpanded() {
        isExpanded.toggle()
        FloatingAssistantPanelManager.shared.updateWindowSize(isExpanded: isExpanded)
    }
    
    public func expandPanel() {
        if !isExpanded {
            isExpanded = true
            FloatingAssistantPanelManager.shared.updateWindowSize(isExpanded: true)
        }
    }
    
    public func collapseToPill() {
        if isExpanded {
            isExpanded = false
            FloatingAssistantPanelManager.shared.updateWindowSize(isExpanded: false)
        }
    }
    
    public func handleUserInput(_ input: String) {
        let intent = IntentRouter.shared.route(input: input)
        AppLogger.shared.info("Routed user input to intent: \(intent)", category: .lifecycle)
        
        switch intent {
        case .cancelTask:
            cancelCurrentTask()
            
        case .clearConversation:
            conversation.clearConversation()
            context.clearAllPendingContext()
            planner.clearPlan()
            setStatus(.idle, message: "Conversation reset.")
            
        case .openSettings:
            isSettingsOpen = true
            
        case .screenAnalysis(let query):
            handleScreenAnalysis(query: query)
            
        case .openApplication(let appName):
            handleOpenApplication(appName: appName)
            
        case .webSearch(let query):
            handleWebSearch(query: query)
            
        case .terminalCommand(let cmd):
            handleTerminalCommand(command: cmd)
            
        case .codingHelp(let query):
            let attached = context.consumePendingContext()
            conversation.sendUserMessage(query, attachedContext: attached, tools: agent.availableTools)
            
        case .chat(let query):
            let attached = context.consumePendingContext()
            conversation.sendUserMessage(query, attachedContext: attached, tools: agent.availableTools)
        }
    }
    
    private func handleScreenAnalysis(query: String) {
        setStatus(.capturing, message: "Capturing screen context...")
        
        Task {
            do {
                let screenContext = try await vision.captureMainDisplay()
                context.attachScreenContext(
                    summary: screenContext.summary,
                    imageBase64: screenContext.imageBase64
                )
                
                let attached = context.consumePendingContext()
                let prompt = query.isEmpty ? "What is currently visible on my screen?" : query
                conversation.sendUserMessage(prompt, attachedContext: attached, tools: agent.availableTools)
            } catch {
                setStatus(.error, message: error.localizedDescription)
                conversation.sendUserMessage("I attempted to inspect your screen, but encountered an error: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleOpenApplication(appName: String) {
        setStatus(.executing, message: "Opening \(appName)...")
        let action = OpenApplicationAction(appName: appName)
        
        Task {
            let result = await executor.executeAction(action, settings: settings, isPrivacyMode: privacy.isPrivacyModeActive)
            if result.success {
                setStatus(.completed, message: "Opened \(appName)")
                conversation.recordDirectInteraction(
                    userInput: "Open \(appName)",
                    assistantResponse: "✓ Successfully opened \(appName)."
                )
            } else {
                setStatus(.error, message: result.errorDescription ?? "Failed to open app")
                conversation.recordDirectInteraction(
                    userInput: "Open \(appName)",
                    assistantResponse: "Failed to open \(appName): \(result.errorDescription ?? "Unknown error")"
                )
            }
        }
    }
    
    private func handleWebSearch(query: String) {
        setStatus(.executing, message: "Searching web for \"\(query)\"...")
        let action = SearchWebAction(query: query)
        
        Task {
            let result = await executor.executeAction(action, settings: settings, isPrivacyMode: privacy.isPrivacyModeActive)
            if result.success {
                setStatus(.completed, message: "Search opened in browser")
                conversation.recordDirectInteraction(
                    userInput: "Search \(query)",
                    assistantResponse: "✓ Opened web search for \"\(query)\" in default browser."
                )
            } else {
                setStatus(.error, message: result.errorDescription ?? "Search failed")
                conversation.recordDirectInteraction(
                    userInput: "Search \(query)",
                    assistantResponse: "Web search failed: \(result.errorDescription ?? "Unknown error")"
                )
            }
        }
    }
    
    private func handleTerminalCommand(command: String) {
        setStatus(.executing, message: "Running: \(command)...")
        let action = RunAllowedCommandAction(command: command)
        
        Task {
            let result = await executor.executeAction(action, settings: settings, isPrivacyMode: privacy.isPrivacyModeActive)
            if result.success {
                setStatus(.completed, message: "Command finished")
                conversation.recordDirectInteraction(
                    userInput: "Run: \(command)",
                    assistantResponse: result.output.isEmpty ? "✓ Command completed with no output." : "```\n\(result.output)\n```"
                )
            } else {
                setStatus(.error, message: result.errorDescription ?? "Command failed")
                conversation.recordDirectInteraction(
                    userInput: "Run: \(command)",
                    assistantResponse: "Command failed: \(result.errorDescription ?? "Error")"
                )
            }
        }
    }
    
    public func toggleVoiceInput() {
        if speech.isListening {
            speech.stopListening()
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                submitCurrentInput()
            } else {
                setStatus(.idle, message: "How can I help?")
            }
        } else {
            // Keep Rio open and expand the panel so user sees the listening interface
            expandPanel()
            
            Task {
                do {
                    try await speech.startListening { [weak self] transcript, isFinal in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.inputText = transcript
                            if isFinal && !transcript.isEmpty {
                                self.submitCurrentInput()
                            }
                        }
                    }
                } catch {
                    AppLogger.shared.error("Voice input error: \(error.localizedDescription)", category: .voice)
                    self.setStatus(.error, message: error.localizedDescription)
                    
                    if let speechErr = error as? SpeechInputError {
                        switch speechErr {
                        case .micPermissionDenied:
                            conversation.recordDirectInteraction(
                                userInput: "🎤 Voice Input",
                                assistantResponse: "⚠️ Microphone access is required. Please grant REO access in **System Settings > Privacy & Security > Microphone**, then try again."
                            )
                            PermissionManager.shared.openSettings(for: .microphone)
                        case .speechPermissionDenied:
                            conversation.recordDirectInteraction(
                                userInput: "🎤 Voice Input",
                                assistantResponse: "⚠️ Speech Recognition permission is required. Please grant REO access in **System Settings > Privacy & Security > Speech Recognition**, then try again."
                            )
                            PermissionManager.shared.openSettings(for: .speechRecognition)
                        case .recognizerUnavailable:
                            conversation.recordDirectInteraction(
                                userInput: "🎤 Voice Input",
                                assistantResponse: "⚠️ Speech recognizer is currently unavailable on this device. Please verify Dictation is enabled in **System Settings > Keyboard > Dictation**."
                            )
                        case .privacyModeActive:
                            conversation.recordDirectInteraction(
                                userInput: "🎤 Voice Input",
                                assistantResponse: "🔒 Voice input is disabled while Privacy Mode is active. You can turn off Privacy Mode in Settings."
                            )
                        case .audioEngineFailed(let msg):
                            conversation.recordDirectInteraction(
                                userInput: "🎤 Voice Input",
                                assistantResponse: "⚠️ Audio system error: \(msg). Please check your default input audio device."
                            )
                        }
                    } else {
                        conversation.recordDirectInteraction(
                            userInput: "🎤 Voice Input",
                            assistantResponse: "⚠️ Voice input encountered an error: \(error.localizedDescription)"
                        )
                    }
                }
            }
        }
    }
    
    public func triggerScreenCapture() {
        Task {
            do {
                setStatus(.capturing, message: "Capturing screen...")
                let screenContext = try await vision.captureMainDisplay()
                context.attachScreenContext(
                    summary: screenContext.summary,
                    imageBase64: screenContext.imageBase64
                )
                setStatus(.idle, message: "Screen context attached.")
            } catch {
                setStatus(.error, message: error.localizedDescription)
            }
        }
    }
    
    public func cancelCurrentTask() {
        conversation.cancelCurrentTask()
        speech.cancelListening()
        tts.stopSpeaking()
        planner.cancelPlan()
        setStatus(.idle, message: "Task cancelled.")
        EventBus.shared.publish(.taskCancelled)
    }
    
    public func togglePanelVisibility() {
        FloatingAssistantPanelManager.shared.toggleVisibility()
        EventBus.shared.publish(.activationToggled)
    }
}
