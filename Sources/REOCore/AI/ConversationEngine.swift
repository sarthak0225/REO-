import Foundation
import SwiftUI

@MainActor
public final class ConversationEngine: ObservableObject {
    public static let shared = ConversationEngine()
    
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var currentStreamingMessageId: UUID? = nil
    @Published public private(set) var currentError: String? = nil
    
    private var activeTask: Task<Void, Never>? = nil
    private var activeProvider: AIProvider
    
    public init(provider: AIProvider = MockAIProvider()) {
        self.activeProvider = provider
    }
    
    public func setProvider(_ provider: AIProvider) {
        self.activeProvider = provider
        AppLogger.shared.info("ConversationEngine switched provider to: \(provider.displayName)", category: .ai)
    }
    
    public func clearConversation() {
        cancelCurrentTask()
        messages.removeAll()
        currentError = nil
        AppLogger.shared.info("Conversation cleared", category: .ai)
    }
    
    public func cancelCurrentTask() {
        if let task = activeTask {
            task.cancel()
            activeTask = nil
        }
        if let streamingId = currentStreamingMessageId {
            if let index = messages.firstIndex(where: { $0.id == streamingId }) {
                messages[index].isStreaming = false
                if messages[index].content.isEmpty {
                    messages[index].content = "[Cancelled]"
                }
            }
        }
        isProcessing = false
        currentStreamingMessageId = nil
        AppLogger.shared.info("Active AI generation task cancelled", category: .ai)
    }
    
    public func sendUserMessage(
        _ text: String,
        attachedContext: AttachedContext? = nil,
        tools: [ToolDefinition]? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachedContext?.screenImageBase64 != nil else { return }
        
        currentError = nil
        
        // Assemble user message content with attached context
        var fullUserContent = trimmed
        if let files = attachedContext?.attachedFiles, !files.isEmpty {
            fullUserContent += "\n\n[Attached Files]:"
            for file in files {
                fullUserContent += "\n--- \(file.filename) ---\n\(file.content)\n---"
            }
        }
        
        if let clipboard = attachedContext?.clipboardText, !clipboard.isEmpty {
            fullUserContent += "\n\n[Clipboard Content]:\n\(clipboard)"
        }
        
        if let screenSummary = attachedContext?.screenSummary, !screenSummary.isEmpty {
            fullUserContent += "\n\n[Visual Context: \(screenSummary)]"
        }
        
        let userMessage = ChatMessage(
            role: .user,
            content: fullUserContent,
            imageBase64: attachedContext?.screenImageBase64
        )
        messages.append(userMessage)
        
        // Prepare assistant message placeholder
        let assistantMessageId = UUID()
        let assistantPlaceholder = ChatMessage(
            id: assistantMessageId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantPlaceholder)
        currentStreamingMessageId = assistantMessageId
        isProcessing = true
        
        let settings = SettingsManager.shared
        let systemPrompt = PromptManager.shared.systemPrompt(
            customInstructions: settings.customSystemInstructions,
            codingMode: false
        )
        
        let model = settings.modelName
        let temperature = settings.temperature
        let isStreaming = settings.streamingEnabled
        let provider = self.activeProvider
        
        activeTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                if isStreaming {
                    let stream = provider.streamMessage(
                        messages: self.messages.filter { $0.id != assistantMessageId },
                        model: model,
                        temperature: temperature,
                        systemPrompt: systemPrompt,
                        tools: tools
                    )
                    
                    for try await chunk in stream {
                        if Task.isCancelled { break }
                        
                        if let delta = chunk.textDelta {
                            self.appendContent(to: assistantMessageId, text: delta)
                        }
                        
                        if let toolCall = chunk.toolCallDelta {
                            self.appendToolCall(to: assistantMessageId, toolCall: toolCall)
                        }
                    }
                } else {
                    let response = try await provider.sendMessage(
                        messages: self.messages.filter { $0.id != assistantMessageId },
                        model: model,
                        temperature: temperature,
                        systemPrompt: systemPrompt,
                        tools: tools
                    )
                    
                    self.setContent(for: assistantMessageId, text: response.text)
                    if let toolCalls = response.toolCalls {
                        for call in toolCalls {
                            self.appendToolCall(to: assistantMessageId, toolCall: call)
                        }
                    }
                }
                
                self.finishStreaming(for: assistantMessageId)
            } catch {
                if !Task.isCancelled {
                    self.handleError(error, for: assistantMessageId)
                }
            }
            
            self.isProcessing = false
            self.currentStreamingMessageId = nil
            self.activeTask = nil
        }
    }
    
    public func recordDirectInteraction(userInput: String, assistantResponse: String) {
        let userMsg = ChatMessage(role: .user, content: userInput)
        let assistantMsg = ChatMessage(role: .assistant, content: assistantResponse)
        messages.append(userMsg)
        messages.append(assistantMsg)
    }
    
    public func addToolResultMessage(toolCallId: String, content: String) {
        let msg = ChatMessage(
            role: .tool,
            content: content,
            toolCallId: toolCallId
        )
        messages.append(msg)
    }
    
    private func appendContent(to id: UUID, text: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content += text
        }
    }
    
    private func setContent(for id: UUID, text: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = text
        }
    }
    
    private func appendToolCall(to id: UUID, toolCall: ToolCall) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            if messages[index].toolCalls == nil {
                messages[index].toolCalls = []
            }
            messages[index].toolCalls?.append(toolCall)
        }
    }
    
    private func finishStreaming(for id: UUID) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].isStreaming = false
            // Purge temporary images from memory in accordance with privacy rules
            messages[index].imageBase64 = nil
            
            // Trigger spoken voice output if enabled
            let responseText = messages[index].content
            if SettingsManager.shared.enableSpokenResponses && !responseText.isEmpty {
                TextToSpeech.shared.speak(text: responseText)
            }
            
            // Execute any pending tool calls generated by the AI
            if let toolCalls = messages[index].toolCalls, !toolCalls.isEmpty {
                executeToolCalls(toolCalls)
            }
        }
    }
    
    private func executeToolCalls(_ toolCalls: [ToolCall]) {
        Task { @MainActor in
            for call in toolCalls {
                AppState.shared.setStatus(.executing, message: "Executing \(call.name)...")
                let result = await AgentEngine.shared.handleToolCall(call)
                
                let resultText = result.success
                    ? (result.output.isEmpty ? "Action '\(call.name)' completed successfully." : result.output)
                    : (result.errorDescription ?? "Action '\(call.name)' failed.")
                
                self.addToolResultMessage(toolCallId: call.id, content: resultText)
                
                if result.success {
                    AppState.shared.setStatus(.completed, message: "Action completed.")
                } else {
                    AppState.shared.setStatus(.error, message: result.errorDescription ?? "Action failed.")
                }
            }
        }
    }
    
    private func handleError(_ error: Error, for id: UUID) {
        let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        currentError = errorDescription
        AppLogger.shared.error("AI Generation error: \(errorDescription)", category: .ai)
        
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].isStreaming = false
            if messages[index].content.isEmpty {
                messages[index].content = "REO encountered an issue: \(errorDescription)"
            }
        }
    }
}
