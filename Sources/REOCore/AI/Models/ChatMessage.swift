import Foundation

public enum MessageRole: String, Codable, Sendable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
}

public struct ToolCall: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let arguments: String
    
    public init(id: String = UUID().uuidString, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ChatMessage: Identifiable, Codable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public let timestamp: Date
    public var toolCalls: [ToolCall]?
    public var toolCallId: String?
    public var imageBase64: String?
    public var isStreaming: Bool
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil,
        imageBase64: String? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.imageBase64 = imageBase64
        self.isStreaming = isStreaming
    }
}
