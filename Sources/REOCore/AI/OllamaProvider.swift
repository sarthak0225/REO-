import Foundation

public final class OllamaProvider: AIProvider, @unchecked Sendable {
    public let providerId: AIProviderType = .ollama
    public let displayName: String = "Local Ollama"
    public let supportedModels: [String] = ["llama3", "llama3.2", "mistral", "qwen2.5-coder", "deepseek-r1"]
    private let baseURL: String
    
    public init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }
    
    public func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            return !data.isEmpty
        } catch {
            return false
        }
    }
    
    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw AIProviderError.invalidConfiguration("Invalid Ollama URL")
        }
        
        let body = buildRequestBody(messages: messages, model: model, systemPrompt: systemPrompt, temperature: temperature, stream: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.networkError("Failed to reach Ollama at \(baseURL)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.decodingError("Invalid Ollama response")
        }
        
        return AIResponse(text: content)
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
                    guard let url = URL(string: "\(self.baseURL)/api/chat") else {
                        continuation.finish(throwing: AIProviderError.invalidConfiguration("Invalid Ollama URL"))
                        return
                    }
                    
                    let body = self.buildRequestBody(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        temperature: temperature,
                        stream: true
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: AIProviderError.networkError("Failed to connect to Ollama"))
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: AIProviderError.cancelled)
                            return
                        }
                        
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(AIStreamChunk(textDelta: content))
                        }
                        
                        if let done = json["done"] as? Bool, done {
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
        systemPrompt: String?,
        temperature: Double,
        stream: Bool
    ) -> [String: Any] {
        var ollamaMessages: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            ollamaMessages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }
        
        for msg in messages {
            var m: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
            if let img = msg.imageBase64, !img.isEmpty {
                m["images"] = [img]
            }
            ollamaMessages.append(m)
        }
        
        return [
            "model": model,
            "messages": ollamaMessages,
            "stream": stream,
            "options": [
                "temperature": temperature
            ]
        ]
    }
}
