import Foundation

public final class GeminiProvider: AIProvider, @unchecked Sendable {
    public let providerId: AIProviderType = .gemini
    public let displayName: String = "Google Gemini"
    public let supportedModels: [String] = ["gemini-flash-latest", "gemini-3.8-flash", "gemini-pro-latest", "gemini-2.5-pro"]
    private let baseURL: String
    private let apiKeyProvider: @Sendable () -> String?
    
    public init(
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta",
        apiKeyProvider: @escaping @Sendable () -> String? = { SecureStorage.shared.getAPIKey(for: .gemini) }
    ) {
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
    }
    
    public func isAvailable() async -> Bool {
        guard let key = apiKeyProvider(), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }
    
    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse {
        guard let apiKey = apiKeyProvider(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingAPIKey
        }
        
        let sanitizedModel = (model.isEmpty || model.hasPrefix("gemini-1.5")) ? "gemini-flash-latest" : model
        guard let url = URL(string: "\(baseURL)/models/\(sanitizedModel):generateContent") else {
            throw AIProviderError.invalidConfiguration("Invalid Gemini URL")
        }
        
        let requestBody = buildRequestBody(
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: temperature,
            tools: tools
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Pass API key via header to avoid query parameter leakage in logs and proxies
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("Invalid HTTP response received from Gemini.")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw parseGeminiError(statusCode: httpResponse.statusCode, data: data)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIProviderError.decodingError("Invalid response structure from Gemini API.")
        }
        
        var fullText = ""
        var toolCalls: [ToolCall] = []
        
        for part in parts {
            if let text = part["text"] as? String {
                fullText += text
            }
            if let functionCall = part["functionCall"] as? [String: Any],
               let funcName = functionCall["name"] as? String,
               let funcArgs = functionCall["args"] as? [String: Any],
               let argsData = try? JSONSerialization.data(withJSONObject: funcArgs),
               let argsString = String(data: argsData, encoding: .utf8) {
                toolCalls.append(ToolCall(name: funcName, arguments: argsString))
            }
        }
        
        return AIResponse(
            text: fullText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
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
                guard let apiKey = self.apiKeyProvider(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.finish(throwing: AIProviderError.missingAPIKey)
                    return
                }
                
                let sanitizedModel = (model.isEmpty || model.hasPrefix("gemini-1.5")) ? "gemini-flash-latest" : model
                guard let url = URL(string: "\(self.baseURL)/models/\(sanitizedModel):streamGenerateContent?alt=sse") else {
                    continuation.finish(throwing: AIProviderError.invalidConfiguration("Invalid Gemini streaming URL"))
                    return
                }
                
                let requestBody = self.buildRequestBody(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    temperature: temperature,
                    tools: tools
                )
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                request.timeoutInterval = 90
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIProviderError.networkError("Invalid streaming HTTP response."))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: self.parseGeminiError(statusCode: httpResponse.statusCode, data: Data()))
                        return
                    }
                    
                    for try await rawLine in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: AIProviderError.cancelled)
                            return
                        }
                        
                        let line = rawLine.trimmingCharacters(in: .whitespaces)
                        guard line.hasPrefix("data:") else { continue }
                        let jsonPayload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard !jsonPayload.isEmpty, let data = jsonPayload.data(using: .utf8) else { continue }
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]] {
                            for part in parts {
                                if let text = part["text"] as? String, !text.isEmpty {
                                    continuation.yield(AIStreamChunk(textDelta: text))
                                }
                                if let functionCall = part["functionCall"] as? [String: Any],
                                   let funcName = functionCall["name"] as? String,
                                   let funcArgs = functionCall["args"] as? [String: Any],
                                   let argsData = try? JSONSerialization.data(withJSONObject: funcArgs),
                                   let argsString = String(data: argsData, encoding: .utf8) {
                                    continuation.yield(AIStreamChunk(toolCallDelta: ToolCall(name: funcName, arguments: argsString)))
                                }
                            }
                        }
                    }
                    
                    continuation.yield(AIStreamChunk(isComplete: true))
                    continuation.finish()
                } catch {
                    // If streaming fails or throws, attempt fallback to standard message
                    if !Task.isCancelled {
                        do {
                            let fallback = try await self.sendMessage(
                                messages: messages,
                                model: model,
                                temperature: temperature,
                                systemPrompt: systemPrompt,
                                tools: tools
                            )
                            continuation.yield(AIStreamChunk(textDelta: fallback.text))
                            if let calls = fallback.toolCalls {
                                for call in calls {
                                    continuation.yield(AIStreamChunk(toolCallDelta: call))
                                }
                            }
                            continuation.yield(AIStreamChunk(isComplete: true))
                            continuation.finish()
                        } catch let fallbackError {
                            continuation.finish(throwing: fallbackError)
                        }
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
    
    private func parseGeminiError(statusCode: Int, data: Data) -> AIProviderError {
        if statusCode == 401 || statusCode == 403 {
            return AIProviderError.invalidConfiguration(
                "Invalid or unauthorized Google Gemini API key. Please check the GEMINI_API_KEY in your .env file or Settings."
            )
        }
        
        if statusCode == 429 {
            return AIProviderError.rateLimited
        }
        
        if statusCode == 500 || statusCode == 503 {
            return AIProviderError.serverError(
                statusCode,
                "Google Gemini service is temporarily overloaded or unavailable. Please try again shortly."
            )
        }
        
        var message = "Gemini API error (HTTP \(statusCode))"
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let errMessage = errorObj["message"] as? String {
            message = errMessage
        }
        
        return AIProviderError.serverError(statusCode, message)
    }
    
    private func buildRequestBody(
        messages: [ChatMessage],
        systemPrompt: String?,
        temperature: Double,
        tools: [ToolDefinition]?
    ) -> [String: Any] {
        var contents: [[String: Any]] = []
        
        for msg in messages {
            guard msg.role != .system else { continue }
            var parts: [[String: Any]] = []
            
            if let imageBase64 = msg.imageBase64, !imageBase64.isEmpty {
                parts.append([
                    "inlineData": [
                        "mimeType": "image/jpeg",
                        "data": imageBase64
                    ]
                ])
            }
            
            if !msg.content.isEmpty {
                parts.append(["text": msg.content])
            }
            
            guard !parts.isEmpty else { continue }
            
            contents.append([
                "role": msg.role == .assistant ? "model" : "user",
                "parts": parts
            ])
        }
        
        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": temperature
            ]
        ]
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        
        if let tools = tools, !tools.isEmpty {
            body["tools"] = buildToolsDeclaration(tools: tools)
        }
        
        return body
    }
    
    private func buildToolsDeclaration(tools: [ToolDefinition]) -> [[String: Any]] {
        var declarations: [[String: Any]] = []
        
        for tool in tools {
            var properties: [String: Any] = [:]
            for (name, param) in tool.parameters {
                properties[name] = [
                    "type": "STRING",
                    "description": param.description
                ]
            }
            
            let decl: [String: Any] = [
                "name": tool.name,
                "description": tool.description,
                "parameters": [
                    "type": "OBJECT",
                    "properties": properties,
                    "required": tool.requiredParameters
                ]
            ]
            declarations.append(decl)
        }
        
        return [["functionDeclarations": declarations]]
    }
}
