import Foundation

public struct ActionResult: Sendable {
    public let success: Bool
    public let output: String
    public let errorDescription: String?
    
    public init(success: Bool, output: String, errorDescription: String? = nil) {
        self.success = success
        self.output = output
        self.errorDescription = errorDescription
    }
}

public protocol Action: Sendable, Identifiable {
    var id: UUID { get }
    var name: String { get }
    var description: String { get }
    var riskLevel: ActionRiskLevel { get }
    var parameters: [String: String] { get }
    var requiresConfirmation: Bool { get }
    
    func execute() async throws -> ActionResult
}

// MARK: - Concrete Actions

public struct OpenApplicationAction: Action {
    public let id: UUID
    public let name: String = "OpenApplication"
    public let appName: String
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Open application: \(appName)" }
    public var parameters: [String: String] { ["appName": appName] }
    
    public init(id: UUID = UUID(), appName: String) {
        self.id = id
        self.appName = appName
    }
    
    public func execute() async throws -> ActionResult {
        return try await ApplicationController.shared.openApplication(named: appName)
    }
}

public struct OpenURLAction: Action {
    public let id: UUID
    public let name: String = "OpenURL"
    public let urlString: String
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Open URL: \(urlString)" }
    public var parameters: [String: String] { ["url": urlString] }
    
    public init(id: UUID = UUID(), urlString: String) {
        self.id = id
        self.urlString = urlString
    }
    
    public func execute() async throws -> ActionResult {
        return try await BrowserController.shared.openURL(urlString)
    }
}

public struct SearchWebAction: Action {
    public let id: UUID
    public let name: String = "SearchWeb"
    public let query: String
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Search web for: \(query)" }
    public var parameters: [String: String] { ["query": query] }
    
    public init(id: UUID = UUID(), query: String) {
        self.id = id
        self.query = query
    }
    
    public func execute() async throws -> ActionResult {
        return try await BrowserController.shared.searchWeb(query: query)
    }
}

public struct SwitchApplicationAction: Action {
    public let id: UUID
    public let name: String = "SwitchApplication"
    public let appName: String
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Switch to application: \(appName)" }
    public var parameters: [String: String] { ["appName": appName] }
    
    public init(id: UUID = UUID(), appName: String) {
        self.id = id
        self.appName = appName
    }
    
    public func execute() async throws -> ActionResult {
        return try await ApplicationController.shared.switchToApplication(named: appName)
    }
}

public struct TypeTextAction: Action {
    public let id: UUID
    public let name: String = "TypeText"
    public let text: String
    public let riskLevel: ActionRiskLevel = .medium
    public var requiresConfirmation: Bool = true
    
    public var description: String { "Type text into active input: \"\(text.prefix(30))...\"" }
    public var parameters: [String: String] { ["textLength": "\(text.count)"] }
    
    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
    
    public func execute() async throws -> ActionResult {
        return try await KeyboardController.shared.typeText(text)
    }
}

public struct PressKeyAction: Action {
    public let id: UUID
    public let name: String = "PressKey"
    public let keyCombination: String
    public let riskLevel: ActionRiskLevel = .medium
    public var requiresConfirmation: Bool = true
    
    public var description: String { "Press keyboard shortcut: \(keyCombination)" }
    public var parameters: [String: String] { ["keys": keyCombination] }
    
    public init(id: UUID = UUID(), keyCombination: String) {
        self.id = id
        self.keyCombination = keyCombination
    }
    
    public func execute() async throws -> ActionResult {
        return try await KeyboardController.shared.pressKey(combination: keyCombination)
    }
}

public struct ClickAction: Action {
    public let id: UUID
    public let name: String = "Click"
    public let x: Double
    public let y: Double
    public let riskLevel: ActionRiskLevel = .medium
    public var requiresConfirmation: Bool = true
    
    public var description: String { "Click mouse at position (\(Int(x)), \(Int(y)))" }
    public var parameters: [String: String] { ["x": "\(x)", "y": "\(y)"] }
    
    public init(id: UUID = UUID(), x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
    
    public func execute() async throws -> ActionResult {
        return try await MouseController.shared.click(x: x, y: y)
    }
}

public struct MoveCursorAction: Action {
    public let id: UUID
    public let name: String = "MoveCursor"
    public let x: Double
    public let y: Double
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Move cursor to (\(Int(x)), \(Int(y)))" }
    public var parameters: [String: String] { ["x": "\(x)", "y": "\(y)"] }
    
    public init(id: UUID = UUID(), x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
    
    public func execute() async throws -> ActionResult {
        return try await MouseController.shared.moveCursor(toX: x, y: y)
    }
}

public struct CreateFileAction: Action {
    public let id: UUID
    public let name: String = "CreateFile"
    public let path: String
    public let content: String
    public let riskLevel: ActionRiskLevel = .medium
    public var requiresConfirmation: Bool = true
    
    public var description: String { "Create or overwrite file at: \(path)" }
    public var parameters: [String: String] { ["path": path, "size": "\(content.count) bytes"] }
    
    public init(id: UUID = UUID(), path: String, content: String) {
        self.id = id
        self.path = path
        self.content = content
    }
    
    public func execute() async throws -> ActionResult {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return ActionResult(success: true, output: "Created file at \(path)")
    }
}

public struct ReadFileAction: Action {
    public let id: UUID
    public let name: String = "ReadFile"
    public let path: String
    public let riskLevel: ActionRiskLevel = .low
    public var requiresConfirmation: Bool = false
    
    public var description: String { "Read file: \(path)" }
    public var parameters: [String: String] { ["path": path] }
    
    public init(id: UUID = UUID(), path: String) {
        self.id = id
        self.path = path
    }
    
    public func execute() async throws -> ActionResult {
        let url = URL(fileURLWithPath: path)
        let text = try String(contentsOf: url, encoding: .utf8)
        let preview = text.count > 500 ? String(text.prefix(500)) + "..." : text
        return ActionResult(success: true, output: preview)
    }
}

public struct RunAllowedCommandAction: Action {
    public let id: UUID
    public let name: String = "RunAllowedCommand"
    public let command: String
    public let riskLevel: ActionRiskLevel
    public var requiresConfirmation: Bool
    
    public var description: String { "Execute shell command: \(command)" }
    public var parameters: [String: String] { ["command": command] }
    
    public init(id: UUID = UUID(), command: String) {
        self.id = id
        self.command = command
        
        // Dynamically classify command risk
        let lower = command.lowercased()
        if lower.contains("rm ") || lower.contains("sudo") || lower.contains("chmod") || lower.contains("kill") || lower.contains("dd ") {
            self.riskLevel = .high
            self.requiresConfirmation = true
        } else if lower.contains("git commit") || lower.contains("git push") || lower.contains("mv ") || lower.contains("cp ") {
            self.riskLevel = .medium
            self.requiresConfirmation = true
        } else {
            self.riskLevel = .low
            self.requiresConfirmation = false
        }
    }
    
    public func execute() async throws -> ActionResult {
        return try await SystemController.shared.runCommand(command)
    }
}
