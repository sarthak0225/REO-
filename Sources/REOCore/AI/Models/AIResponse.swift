import Foundation

public struct ToolParameter: Codable, Sendable {
    public let type: String
    public let description: String
    public let `enum`: [String]?
    
    public init(type: String, description: String, `enum`: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}

public struct ToolDefinition: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let parameters: [String: ToolParameter]
    public let requiredParameters: [String]
    
    public init(
        name: String,
        description: String,
        parameters: [String: ToolParameter] = [:],
        requiredParameters: [String] = []
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.requiredParameters = requiredParameters
    }
}

public struct AIResponse: Sendable {
    public let text: String
    public let toolCalls: [ToolCall]?
    public let finishReason: String?
    public let promptTokens: Int?
    public let completionTokens: Int?
    
    public init(
        text: String,
        toolCalls: [ToolCall]? = nil,
        finishReason: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}

public struct AIStreamChunk: Sendable {
    public let textDelta: String?
    public let toolCallDelta: ToolCall?
    public let isComplete: Bool
    
    public init(textDelta: String? = nil, toolCallDelta: ToolCall? = nil, isComplete: Bool = false) {
        self.textDelta = textDelta
        self.toolCallDelta = toolCallDelta
        self.isComplete = isComplete
    }
}
