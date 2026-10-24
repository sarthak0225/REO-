import Foundation

public final class MockAIProvider: AIProvider, @unchecked Sendable {
    public let providerId: AIProviderType = .mock
    public let displayName: String = "Mock / Offline Mode"
    public let supportedModels: [String] = ["mock-reo-v1", "mock-fast", "mock-agentic"]
    
    public var customResponseGenerator: (@Sendable ([ChatMessage]) -> AIResponse)? = nil
    
    public init() {}
    
    public func isAvailable() async -> Bool {
        return true
    }
    
    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse {
        if let custom = customResponseGenerator {
            return custom(messages)
        }
        
        let lastUserMessage = messages.last(where: { $0.role == .user })?.content ?? ""
        let responseText = generateMockResponse(for: lastUserMessage, hasTools: tools != nil && !tools!.isEmpty)
        
        return AIResponse(
            text: responseText,
            toolCalls: detectMockToolCalls(for: lastUserMessage, tools: tools),
            finishReason: "stop",
            promptTokens: 42,
            completionTokens: 88
        )
    }
    
    public func streamMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) -> AsyncThrowingStream<AIStreamChunk, Error> {
        let lastUserMessage = messages.last(where: { $0.role == .user })?.content ?? ""
        let fullResponse = generateMockResponse(for: lastUserMessage, hasTools: tools != nil && !tools!.isEmpty)
        let toolCalls = detectMockToolCalls(for: lastUserMessage, tools: tools)
        
        return AsyncThrowingStream { continuation in
            Task {
                let words = fullResponse.components(separatedBy: " ")
                for (index, word) in words.enumerated() {
                    if Task.isCancelled {
                        continuation.finish(throwing: AIProviderError.cancelled)
                        return
                    }
                    
                    let chunkText = index == 0 ? word : " " + word
                    continuation.yield(AIStreamChunk(textDelta: chunkText))
                    
                    // Simulate fast realistic streaming
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                }
                
                if let toolCalls = toolCalls {
                    for call in toolCalls {
                        continuation.yield(AIStreamChunk(toolCallDelta: call))
                    }
                }
                
                continuation.yield(AIStreamChunk(isComplete: true))
                continuation.finish()
            }
        }
    }
    
    private func generateMockResponse(for query: String, hasTools: Bool) -> String {
        let lower = query.lowercased()
        
        if lower.contains("screen") || lower.contains("look") || lower.contains("see") {
            return "I inspected your screen context. You are working in your development environment. All systems appear normal and responsive."
        } else if lower.contains("open") || lower.contains("launch") {
            return "Executing your application request..."
        } else if lower.contains("code") || lower.contains("error") || lower.contains("bug") {
            return "Let's review the code. The logic follows modern Swift patterns: check concurrency actor boundaries and ensure weak self captures inside asynchronous closures."
        } else if lower.contains("help") || lower.contains("who are you") {
            return "I am REO (Reasoning & Execution Orchestrator), your personal native macOS AI assistant. I am currently running in Offline / Mock Mode. To connect real AI models (Gemini, Claude, GPT-4o, Ollama), click the Settings gear icon (⚙️) above and add your API key."
        } else {
            return "Understood: \"\(query)\".\n\n*(Note: REO is currently in Offline / Mock Mode. To enable full generative AI answers, click the Settings gear ⚙️ and configure Google Gemini, Claude, or OpenAI.)*"
        }
    }
    
    private func detectMockToolCalls(for query: String, tools: [ToolDefinition]?) -> [ToolCall]? {
        guard let tools = tools, !tools.isEmpty else { return nil }
        let lower = query.lowercased()
        
        if lower.contains("open ") || lower.contains("launch ") {
            let words = lower.components(separatedBy: " ")
            if let idx = words.firstIndex(where: { $0 == "open" || $0 == "launch" }), idx + 1 < words.count {
                let target = words[idx + 1].capitalized
                return [ToolCall(name: "open_application", arguments: "{\"appName\":\"\(target)\"}")]
            }
        }
        
        if lower.contains("search ") || lower.contains("google ") {
            return [ToolCall(name: "search_web", arguments: "{\"query\":\"\(query)\"}")]
        }
        return nil
    }
}
