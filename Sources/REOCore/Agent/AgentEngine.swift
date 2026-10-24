import Foundation
import SwiftUI

@MainActor
public final class AgentEngine: ObservableObject {
    public static let shared = AgentEngine()
    
    @Published public private(set) var isAgentActive: Bool = false
    @Published public private(set) var currentActionName: String? = nil
    
    public let availableTools: [ToolDefinition] = [
        ToolDefinition(
            name: "open_application",
            description: "Opens or launches an application on macOS by name.",
            parameters: ["appName": ToolParameter(type: "string", description: "The name of the app to launch (e.g. Safari, Xcode, Notes)")],
            requiredParameters: ["appName"]
        ),
        ToolDefinition(
            name: "open_url",
            description: "Opens a web address in the default web browser.",
            parameters: ["url": ToolParameter(type: "string", description: "The complete URL to open")],
            requiredParameters: ["url"]
        ),
        ToolDefinition(
            name: "search_web",
            description: "Searches Google using the default browser.",
            parameters: ["query": ToolParameter(type: "string", description: "Search query text")],
            requiredParameters: ["query"]
        ),
        ToolDefinition(
            name: "switch_application",
            description: "Brings a running application to the foreground.",
            parameters: ["appName": ToolParameter(type: "string", description: "The application to switch to")],
            requiredParameters: ["appName"]
        ),
        ToolDefinition(
            name: "run_command",
            description: "Executes a safe shell command on macOS and returns the output.",
            parameters: ["command": ToolParameter(type: "string", description: "The terminal command to run")],
            requiredParameters: ["command"]
        ),
        ToolDefinition(
            name: "read_file",
            description: "Reads the text contents of a file at the specified path.",
            parameters: ["path": ToolParameter(type: "string", description: "Absolute path to the file")],
            requiredParameters: ["path"]
        ),
        ToolDefinition(
            name: "create_file",
            description: "Creates or writes text content to a file at the specified path.",
            parameters: [
                "path": ToolParameter(type: "string", description: "Absolute path to destination file"),
                "content": ToolParameter(type: "string", description: "Text content to write")
            ],
            requiredParameters: ["path", "content"]
        )
    ]
    
    private init() {}
    
    public func handleToolCall(_ toolCall: ToolCall) async -> ActionResult {
        isAgentActive = true
        currentActionName = toolCall.name
        defer {
            isAgentActive = false
            currentActionName = nil
        }
        
        guard let action = parseToolCallToAction(toolCall) else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Unknown or malformed tool call: \(toolCall.name)"
            )
        }
        
        let result = await ActionExecutor.shared.executeAction(action)
        return result
    }
    
    private func parseToolCallToAction(_ toolCall: ToolCall) -> (any Action)? {
        guard let data = toolCall.arguments.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        
        switch toolCall.name {
        case "open_application":
            if let appName = dict["appName"] as? String {
                return OpenApplicationAction(appName: appName)
            }
        case "open_url":
            if let url = dict["url"] as? String {
                return OpenURLAction(urlString: url)
            }
        case "search_web":
            if let query = dict["query"] as? String {
                return SearchWebAction(query: query)
            }
        case "switch_application":
            if let appName = dict["appName"] as? String {
                return SwitchApplicationAction(appName: appName)
            }
        case "run_command":
            if let command = dict["command"] as? String {
                return RunAllowedCommandAction(command: command)
            }
        case "read_file":
            if let path = dict["path"] as? String {
                return ReadFileAction(path: path)
            }
        case "create_file":
            if let path = dict["path"] as? String, let content = dict["content"] as? String {
                return CreateFileAction(path: path, content: content)
            }
        default:
            return nil
        }
        return nil
    }
}
