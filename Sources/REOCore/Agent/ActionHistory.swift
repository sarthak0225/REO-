import Foundation
import SwiftUI

public struct ActionHistoryEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let actionName: String
    public let description: String
    public let riskLevel: ActionRiskLevel
    public let success: Bool
    public let outputSnippet: String
    
    public init(
        timestamp: Date = Date(),
        actionName: String,
        description: String,
        riskLevel: ActionRiskLevel,
        success: Bool,
        outputSnippet: String
    ) {
        self.timestamp = timestamp
        self.actionName = actionName
        self.description = description
        self.riskLevel = riskLevel
        self.success = success
        self.outputSnippet = outputSnippet
    }
}

@MainActor
public final class ActionHistory: ObservableObject {
    public static let shared = ActionHistory()
    
    @Published public private(set) var entries: [ActionHistoryEntry] = []
    
    private init() {}
    
    public func record(action: any Action, result: ActionResult) {
        let snippet = result.errorDescription ?? String(result.output.prefix(120))
        let entry = ActionHistoryEntry(
            actionName: action.name,
            description: action.description,
            riskLevel: action.riskLevel,
            success: result.success,
            outputSnippet: snippet
        )
        entries.insert(entry, at: 0) // Most recent first
        AppLogger.shared.info("Recorded action history: \(action.name) (success: \(result.success))", category: .agent)
    }
    
    public func clearHistory() {
        entries.removeAll()
        AppLogger.shared.info("Action history cleared by user", category: .agent)
    }
}
