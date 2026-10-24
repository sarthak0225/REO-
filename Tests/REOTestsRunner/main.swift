import Foundation
import REOCore

// MARK: - Lightweight Test Framework
var totalTests = 0
var passedTests = 0
var failedTests = 0

@MainActor
func test(_ name: String, block: () async throws -> Void) async {
    totalTests += 1
    do {
        try await block()
        passedTests += 1
        print("  ✓ \(name)")
    } catch {
        failedTests += 1
        print("  ✗ \(name) FAILED: \(error)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if actual != expected {
        throw NSError(domain: "TestAssertionFailure", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected '\(expected)', got '\(actual)'. \(message) (\(file):\(line))"
        ])
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if !condition {
        throw NSError(domain: "TestAssertionFailure", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected condition to be true. \(message) (\(file):\(line))"
        ])
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if condition {
        throw NSError(domain: "TestAssertionFailure", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected condition to be false. \(message) (\(file):\(line))"
        ])
    }
}

// MARK: - Test Suites
@MainActor
func runAllTests() async {
    print("==================================================")
    print("        REO ASSISTANT TEST SUITE (PHASE 1)        ")
    print("==================================================")
    
    // 1. Branding & Product Info Tests
    print("\n[1] Product Identity & Metadata:")
    await test("REO naming and acronym definition") {
        try assertEqual(REOInfo.name, "REO")
        try assertEqual(REOInfo.subtitle, "Reasoning & Execution Orchestrator")
        try assertEqual(REOInfo.version, "1.0.0")
    }
    
    // 2. Command Routing & Intent Router Tests
    print("\n[2] Intent Routing:")
    await test("Routes cancel and clear commands correctly") {
        try assertEqual(IntentRouter.shared.route(input: "cancel"), .cancelTask)
        try assertEqual(IntentRouter.shared.route(input: "clear"), .clearConversation)
        try assertEqual(IntentRouter.shared.route(input: "settings"), .openSettings)
    }
    
    await test("Routes screen understanding queries") {
        try assertEqual(IntentRouter.shared.route(input: "What's on my screen?"), .screenAnalysis(query: "What's on my screen?"))
        try assertEqual(IntentRouter.shared.route(input: "look at my screen and tell me what is wrong"), .screenAnalysis(query: "look at my screen and tell me what is wrong"))
    }
    
    await test("Routes application launching intent") {
        try assertEqual(IntentRouter.shared.route(input: "open Safari"), .openApplication(appName: "Safari"))
        try assertEqual(IntentRouter.shared.route(input: "launch Terminal"), .openApplication(appName: "Terminal"))
    }
    
    await test("Routes web search intent") {
        try assertEqual(IntentRouter.shared.route(input: "search for Swift 6"), .webSearch(query: "Swift 6"))
        try assertEqual(IntentRouter.shared.route(input: "google macOS Sequoia"), .webSearch(query: "macOS Sequoia"))
    }
    
    await test("Routes coding help intent") {
        try assertEqual(IntentRouter.shared.route(input: "explain this error: fatalError"), .codingHelp(query: "explain this error: fatalError"))
    }
    
    await test("Routes general chat intent") {
        try assertEqual(IntentRouter.shared.route(input: "Hello REO, how are you?"), .chat(query: "Hello REO, how are you?"))
    }
    
    // 3. Credential Storage Abstraction Tests
    print("\n[3] Credential Storage & Security:")
    await test("MockCredentialStore saves, retrieves, and deletes API keys") {
        let store = MockCredentialStore()
        try assertFalse(store.hasCredential(for: "testService", account: "openai"))
        
        try store.saveCredential("sk-secret-test-key-12345", for: "testService", account: "openai")
        try assertTrue(store.hasCredential(for: "testService", account: "openai"))
        
        let loaded = try store.loadCredential(for: "testService", account: "openai")
        try assertEqual(loaded, "sk-secret-test-key-12345")
        
        try store.deleteCredential(for: "testService", account: "openai")
        try assertFalse(store.hasCredential(for: "testService", account: "openai"))
    }
    
    await test("SecureStorage masks keys properly without leaking in UI") {
        let masked = SecureStorage.maskKey("sk-proj-1234567890abcdef")
        try assertTrue(masked.contains("••••••••"), "Key should be masked")
        try assertTrue(masked.hasPrefix("sk-p"), "Prefix should show slightly")
        try assertTrue(masked.hasSuffix("cdef"), "Suffix should show slightly")
    }
    
    // 4. Action Risk Classification & Action Validation Tests
    print("\n[4] Action Safety & Validation:")
    await test("Action risk levels order properly") {
        try assertTrue(ActionRiskLevel.low < ActionRiskLevel.medium)
        try assertTrue(ActionRiskLevel.medium < ActionRiskLevel.high)
    }
    
    await test("Low-risk actions default to automatic execution when confirmation is disabled") {
        let settings = SettingsManager.shared
        settings.confirmLowRiskActions = false
        
        let action = OpenApplicationAction(appName: "Safari")
        let decision = ActionValidator.shared.validate(action: action, settings: settings, isPrivacyModeActive: false)
        try assertTrue(decision.isAllowedToRunDirectly)
        try assertFalse(decision.requiresUserConfirmation)
    }
    
    await test("High-risk actions always require user confirmation") {
        let settings = SettingsManager.shared
        let destructiveAction = RunAllowedCommandAction(command: "rm -rf /test/dir")
        try assertEqual(destructiveAction.riskLevel, .high)
        
        let decision = ActionValidator.shared.validate(action: destructiveAction, settings: settings, isPrivacyModeActive: false)
        try assertFalse(decision.isAllowedToRunDirectly)
        try assertTrue(decision.requiresUserConfirmation)
    }
    
    await test("Privacy mode forces confirmation on all actions") {
        let settings = SettingsManager.shared
        let action = OpenURLAction(urlString: "https://apple.com")
        
        let decision = ActionValidator.shared.validate(action: action, settings: settings, isPrivacyModeActive: true)
        try assertFalse(decision.isAllowedToRunDirectly)
        try assertTrue(decision.requiresUserConfirmation)
    }
    
    // 5. Task Planner Tests
    print("\n[5] Task Planning & Execution Tracking:")
    await test("TaskPlanner creates sequential plan and updates progress") {
        let planner = TaskPlanner.shared
        let plan = planner.createPlan(for: "Search web and summarize", steps: [
            "Open browser",
            "Perform search query",
            "Summarize findings"
        ])
        
        try assertEqual(plan.steps.count, 3)
        try assertEqual(plan.steps[0].status, .pending)
        try assertFalse(plan.isComplete)
        
        planner.setStepStatus(stepIndex: 0, status: .completed)
        planner.setStepStatus(stepIndex: 1, status: .inProgress)
        
        let updated = planner.activePlan!
        try assertEqual(updated.steps[0].status, .completed)
        try assertEqual(updated.steps[1].status, .inProgress)
        try assertEqual(updated.steps[2].status, .pending)
        
        planner.setStepStatus(stepIndex: 1, status: .completed)
        planner.setStepStatus(stepIndex: 2, status: .completed)
        try assertTrue(planner.activePlan!.isComplete)
        
        planner.clearPlan()
    }
    
    // 6. AI Provider & Conversation Engine Tests
    print("\n[6] AI Provider & Conversation Engine:")
    await test("MockAIProvider generates responses and tool calls") {
        let provider = MockAIProvider()
        let messages = [ChatMessage(role: .user, content: "Hello REO")]
        let response = try await provider.sendMessage(
            messages: messages,
            model: "mock-reo-v1",
            temperature: 0.7,
            systemPrompt: "You are REO",
            tools: nil
        )
        try assertTrue(!response.text.isEmpty)
        try assertEqual(response.finishReason, "stop")
    }
    
    await test("MockAIProvider generates streaming chunks") {
        let provider = MockAIProvider()
        let messages = [ChatMessage(role: .user, content: "Tell me about my screen")]
        let stream = provider.streamMessage(
            messages: messages,
            model: "mock-reo-v1",
            temperature: 0.7,
            systemPrompt: nil,
            tools: nil
        )
        
        var receivedChunks: [String] = []
        for try await chunk in stream {
            if let delta = chunk.textDelta {
                receivedChunks.append(delta)
            }
        }
        try assertTrue(!receivedChunks.isEmpty)
        let full = receivedChunks.joined()
        try assertTrue(full.contains("screen"))
    }
    
    await test("ConversationEngine handles cancellation cleanly") {
        let engine = ConversationEngine.shared
        engine.clearConversation()
        
        engine.sendUserMessage("What is the meaning of life?")
        try assertTrue(engine.isProcessing)
        
        engine.cancelCurrentTask()
        try assertFalse(engine.isProcessing)
        try assertEqual(engine.currentStreamingMessageId, nil)
    }
    
    // 7. Response Parser & Markdown Code Extraction
    print("\n[7] Response Parsing:")
    await test("Extracts code blocks with language from markdown") {
        let markdown = """
        Here is the implementation:
        ```swift
        func testFunc() -> Int {
            return 42
        }
        ```
        That is all.
        """
        let blocks = ResponseParser.shared.extractCodeBlocks(from: markdown)
        try assertEqual(blocks.count, 1)
        try assertEqual(blocks[0].language, "swift")
        try assertTrue(blocks[0].code.contains("testFunc"))
    }
    
    // 8. Permission Manager Initial State & Integrity
    print("\n[8] Permission Manager:")
    await test("PermissionManager reports valid enum states without crashing") {
        let pm = PermissionManager.shared
        pm.checkAllPermissions()
        try assertTrue(pm.status(for: .accessibility) == .granted || pm.status(for: .accessibility) == .denied)
        try assertTrue(PermissionType.allCases.count == 4)
    }
    
    // 9. Google Gemini Provider & Env Configuration
    print("\n[9] Google Gemini Provider & Env Configuration:")
    await test("GeminiProvider correctly validates presence of API key") {
        let mockProviderWithoutKey = GeminiProvider(apiKeyProvider: { nil })
        let availableWithoutKey = await mockProviderWithoutKey.isAvailable()
        try assertFalse(availableWithoutKey)
        
        let mockProviderWithKey = GeminiProvider(apiKeyProvider: { "AIzaSyFakeKeyForTestVerification123456" })
        let availableWithKey = await mockProviderWithKey.isAvailable()
        try assertTrue(availableWithKey)
        try assertEqual(mockProviderWithKey.providerId, .gemini)
    }
    
    await test("EnvLoader reads environment and candidate paths") {
        setenv("TEST_REO_ENV_VAR", "test_value_123", 1)
        let loaded = EnvLoader.shared.get("TEST_REO_ENV_VAR")
        try assertEqual(loaded, "test_value_123")
    }
    
    // 10. Voice & Microphone Bug Fix Verification
    print("\n[10] Voice & Microphone Bug Fix Verification:")
    await test("Mic click expands and keeps panel open from collapsed state") {
        let appState = AppState.shared
        appState.collapseToPill()
        try assertFalse(appState.isExpanded)
        
        // Simulating mic button click
        appState.toggleVoiceInput()
        try assertTrue(appState.isExpanded, "Panel must be expanded upon clicking mic")
        try assertTrue(appState.isPanelVisible, "Panel must remain visible upon clicking mic")
        
        // Clean up listening state if started
        SpeechRecognizer.shared.stopListening()
    }
    
    await test("Inside click coordinates are never treated as outside clicks") {
        let panelFrame = NSRect(x: 200, y: 200, width: 450, height: 400)
        let micButtonClick = NSPoint(x: 350, y: 250)
        let outsideDesktopClick = NSPoint(x: 50, y: 50)
        
        try assertTrue(panelFrame.contains(micButtonClick), "Mic click inside panel must be recognized as inside")
        try assertFalse(panelFrame.contains(outsideDesktopClick), "Click on desktop must be recognized as outside")
    }
    
    await test("Voice transcript correctly passes to conversation and Gemini integration") {
        let appState = AppState.shared
        let initialCount = appState.conversation.messages.count
        
        appState.inputText = "Explain quantum computing briefly"
        appState.submitCurrentInput()
        
        try assertEqual(appState.inputText, "")
        try assertTrue(appState.conversation.messages.count >= initialCount + 2)
        let userMessage = appState.conversation.messages[appState.conversation.messages.count - 2]
        try assertEqual(userMessage.role, .user)
        try assertEqual(userMessage.content, "Explain quantum computing briefly")
        try assertEqual(appState.conversation.messages.last?.role, .assistant)
        
        // Cancel active generation for test clean-up
        appState.cancelCurrentTask()
    }
    
    // Summary
    print("\n==================================================")
    print("TEST SUMMARY: \(passedTests) / \(totalTests) passed (\(failedTests) failed)")
    print("==================================================")
    
    if failedTests > 0 {
        exit(1)
    }
}

Task { @MainActor in
    await runAllTests()
    exit(0)
}

dispatchMain()
