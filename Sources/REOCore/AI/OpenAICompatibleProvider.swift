import Foundation

public final class OpenAICompatibleProvider: AIProvider, @unchecked Sendable {
    public let providerId: AIProviderType
    public let displayName: String
    public let supportedModels: [String]
    private let baseURL: String
    private let apiKeyProvider: @Sendable () -> String?
    
    public init(
        providerId: AIProviderType = .openAI,
        displayName: String = "OpenAI Compatible",
        baseURL: String = "https://api.openai.com/v1",
        supportedModels: [String] = ["gpt-4o", "gpt-4o-mini", "o3-mini"],
        apiKeyProvider: @escaping @Sendable () -> String? = { SecureStorage.shared.getAPIKey(for: .openAI) }
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.baseURL = baseURL
        self.supportedModels = supportedModels
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
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIProviderError.invalidConfiguration("Invalid Base URL: \(baseURL)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AIProviderError.decodingError("Could not parse choices from response")
        }
        
        let content = message["content"] as? String ?? ""
        let finishReason = firstChoice["finish_reason"] as? String
        
        var toolCalls: [ToolCall]? = nil
        if let rawCalls = message["tool_calls"] as? [[String: Any]] {
            toolCalls = rawCalls.compactMap { raw in
                guard let id = raw["id"] as? String,
                      let function = raw["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let args = function["arguments"] as? String else { return nil }
                return ToolCall(id: id, name: name, arguments: args)
            }
        }
        
        var promptTokens: Int? = nil
        var completionTokens: Int? = nil
        if let usage = json["usage"] as? [String: Any] {
            promptTokens = usage["prompt_tokens"] as? Int
            completionTokens = usage["completion_tokens"] as? Int
        }
        
        return AIResponse(
            text: content,
            toolCalls: toolCalls,
            finishReason: finishReason,
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
                    
                    guard let url = URL(string: "\(self.baseURL)/chat/completions") else {
                        continuation.finish(throwing: AIProviderError.invalidConfiguration("Invalid Base URL"))
                        return
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                        
                        if payload == "[DONE]" {
                            continuation.yield(AIStreamChunk(isComplete: true))
                            continuation.finish()
                            return
                        }
                        
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let first = choices.first,
                              let delta = first["delta"] as? [String: Any] else {
                            continue
                        }
                        
                        if let textDelta = delta["content"] as? String {
                            continuation.yield(AIStreamChunk(textDelta: textDelta))
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
        var formattedMessages: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            formattedMessages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }
        
        for msg in messages {
            var msgDict: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
            
            // Support image/vision payloads
            if let imageBase64 = msg.imageBase64, !imageBase64.isEmpty {
                msgDict["content"] = [
                    [
                        "type": "text",
                        "text": msg.content
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(imageBase64)"
                        ]
                    ]
                ]
            }
            
            if let toolCallId = msg.toolCallId {
                msgDict["tool_call_id"] = toolCallId
            }
            
            formattedMessages.append(msgDict)
        }
        
        var body: [String: Any] = [
            "model": model,
            "messages": formattedMessages,
            "temperature": temperature,
            "stream": stream
        ]
        
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                var props: [String: Any] = [:]
                for (paramName, param) in tool.parameters {
                    var pDict: [String: Any] = [
                        "type": param.type,
                        "description": param.description
                    ]
                    if let enumVals = param.enum {
                        pDict["enum"] = enumVals
                    }
                    props[paramName] = pDict
                }
                
                return [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": [
                            "type": "object",
                            "properties": props,
                            "required": tool.requiredParameters
                        ]
                    ]
                ]
            }
        }
        
        return body
    }
}
