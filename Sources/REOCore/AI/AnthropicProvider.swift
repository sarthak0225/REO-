import Foundation

public final class AnthropicProvider: AIProvider, @unchecked Sendable {
    public let providerId: AIProviderType = .anthropic
    public let displayName: String = "Anthropic Claude"
    public let supportedModels: [String] = [
        "claude-3-7-sonnet-20250219",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022"
    ]
    private let baseURL: String
    private let apiKeyProvider: @Sendable () -> String?
    
    public init(
        baseURL: String = "https://api.anthropic.com/v1",
        apiKeyProvider: @escaping @Sendable () -> String? = { SecureStorage.shared.getAPIKey(for: .anthropic) }
    ) {
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
    }
    
    public func isAvailable() async -> Bool {
        guard let key = apiKeyProvider(), !key.isEmpty else { return false }
        return true
    }
    
    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }
        
        let requestBody = buildRequestBody(
            messages: messages,
            model: model,
            temperature: temperature,
            systemPrompt: systemPrompt,
            tools: tools,
            stream: false
        )
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AIProviderError.invalidConfiguration("Invalid Base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("Invalid HTTP response")
        }
        
        if httpResponse.statusCode == 429 {
            throw AIProviderError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AIProviderError.serverError(httpResponse.statusCode, errorText)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AIProviderError.decodingError("Invalid response JSON from Anthropic")
        }
        
        var fullText = ""
        var toolCalls: [ToolCall] = []
        
        for block in contentBlocks {
            let type = block["type"] as? String ?? ""
            if type == "text", let text = block["text"] as? String {
                fullText += text
            } else if type == "tool_use",
                      let id = block["id"] as? String,
                      let name = block["name"] as? String,
                      let input = block["input"] as? [String: Any],
                      let inputData = try? JSONSerialization.data(withJSONObject: input),
                      let inputString = String(data: inputData, encoding: .utf8) {
                toolCalls.append(ToolCall(id: id, name: name, arguments: inputString))
            }
        }
        
        let stopReason = json["stop_reason"] as? String
        var promptTokens: Int? = nil
        var completionTokens: Int? = nil
        if let usage = json["usage"] as? [String: Any] {
            promptTokens = usage["input_tokens"] as? Int
            completionTokens = usage["output_tokens"] as? Int
        }
        
        return AIResponse(
            text: fullText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            finishReason: stopReason,
            promptTokens: promptTokens,
            completionTokens: completionTokens
        )
    }
    
    public func streamMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = self.apiKeyProvider(), !apiKey.isEmpty else {
                        continuation.finish(throwing: AIProviderError.missingAPIKey)
                        return
                    }
                    
                    let requestBody = self.buildRequestBody(
                        messages: messages,
                        model: model,
                        temperature: temperature,
                        systemPrompt: systemPrompt,
                        tools: tools,
                        stream: true
                    )
                    
                    guard let url = URL(string: "\(self.baseURL)/messages") else {
                        continuation.finish(throwing: AIProviderError.invalidConfiguration("Invalid Base URL"))
                        return
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AIProviderError.networkError("Streaming connection failed"))
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: AIProviderError.cancelled)
                            return
                        }
                        
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let payload = String(trimmed.dropFirst(6))
                        
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }
                        
                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let deltaType = delta["type"] as? String,
                           deltaType == "text_delta",
                           let text = delta["text"] as? String {
                            continuation.yield(AIStreamChunk(textDelta: text))
                        } else if type == "message_stop" {
                            continuation.yield(AIStreamChunk(isComplete: true))
                            continuation.finish()
                            return
                        }
                    }
                    
                    continuation.yield(AIStreamChunk(isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?,
        stream: Bool
    ) -> [String: Any] {
        var anthropicMessages: [[String: Any]] = []
        
        for msg in messages {
            // Anthropic separates system prompt into top-level key
            guard msg.role != .system else { continue }
            
            var contentBlocks: [[String: Any]] = []
            
            if let imageBase64 = msg.imageBase64, !imageBase64.isEmpty {
                contentBlocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": imageBase64
                    ]
                ])
            }
            
            if !msg.content.isEmpty {
                contentBlocks.append([
                    "type": "text",
                    "text": msg.content
                ])
            }
            
            anthropicMessages.append([
                "role": msg.role == .assistant ? "assistant" : "user",
                "content": contentBlocks
            ])
        }
        
        var body: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "max_tokens": 4096,
            "temperature": temperature,
            "stream": stream
        ]
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }
        
        return body
    }
}
