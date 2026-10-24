import Foundation

public enum AIProviderError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidConfiguration(String)
    case networkError(String)
    case rateLimited
    case serverError(Int, String)
    case decodingError(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found for this provider. Please add your API key in Settings."
        case .invalidConfiguration(let msg):
            return "Invalid provider configuration: \(msg)"
        case .networkError(let msg):
            return "REO could not reach the AI service: \(msg)"
        case .rateLimited:
            return "Rate limit exceeded. Please wait a moment before trying again."
        case .serverError(let code, let msg):
            return "Service error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Failed to process AI response: \(msg)"
        case .cancelled:
            return "Request was cancelled."
        }
    }
}

public protocol AIProvider: Sendable {
    var providerId: AIProviderType { get }
    var displayName: String { get }
    var supportedModels: [String] { get }
    
    func sendMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse
    
    func streamMessage(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        systemPrompt: String?,
        tools: [ToolDefinition]?
    ) -> AsyncThrowingStream<AIStreamChunk, Error>
    
    func isAvailable() async -> Bool
}
