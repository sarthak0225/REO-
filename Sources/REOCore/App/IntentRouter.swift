import Foundation

public enum UserIntent: Sendable, Equatable {
    case chat(query: String)
    case screenAnalysis(query: String)
    case openApplication(appName: String)
    case webSearch(query: String)
    case codingHelp(query: String)
    case terminalCommand(command: String)
    case openSettings
    case clearConversation
    case cancelTask
}

public final class IntentRouter: Sendable {
    public static let shared = IntentRouter()
    
    private init() {}
    
    public func route(input: String) -> UserIntent {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        if lower == "cancel" || lower == "stop" || lower == "quit current task" {
            return .cancelTask
        }
        
        if lower == "clear" || lower == "clear conversation" || lower == "reset" {
            return .clearConversation
        }
        
        if lower == "settings" || lower == "open settings" || lower == "preferences" {
            return .openSettings
        }
        
        // Screen analysis commands
        if lower.contains("look at my screen") ||
            lower.contains("what's on my screen") ||
            lower.contains("whats on my screen") ||
            lower.contains("look at screen") ||
            lower.contains("explain screen") ||
            lower.contains("see my screen") {
            return .screenAnalysis(query: trimmed)
        }
        
        // Natural language normalization with case preservation
        var workingText = trimmed
        for prefix in ["please ", "can you ", "could you ", "hey reo, ", "reo, ", "kindly "] {
            if workingText.lowercased().hasPrefix(prefix) {
                workingText = String(workingText.dropFirst(prefix.count))
            }
        }
        
        let lowerWorking = workingText.lowercased()
        
        // Open application commands (e.g. "open Safari", "can you open Notes", "launch Terminal")
        if lowerWorking.hasPrefix("open up ") {
            let appQuery = String(workingText.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !appQuery.isEmpty && !appQuery.hasPrefix("http") && !appQuery.contains(".com") {
                return .openApplication(appName: appQuery)
            }
        } else if lowerWorking.hasPrefix("open ") {
            let appQuery = String(workingText.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !appQuery.isEmpty && !appQuery.hasPrefix("http") && !appQuery.contains(".com") {
                return .openApplication(appName: appQuery)
            }
        } else if lowerWorking.hasPrefix("launch ") {
            let appQuery = String(workingText.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !appQuery.isEmpty && !appQuery.hasPrefix("http") && !appQuery.contains(".com") {
                return .openApplication(appName: appQuery)
            }
        }
        
        // Web search commands (e.g. "search for Swift 6 concurrency", "google Apple news", "look up weather")
        if lowerWorking.hasPrefix("search for ") {
            let query = String(workingText.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .webSearch(query: query)
        } else if lowerWorking.hasPrefix("search ") {
            let query = String(workingText.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .webSearch(query: query)
        } else if lowerWorking.hasPrefix("look up ") {
            let query = String(workingText.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .webSearch(query: query)
        } else if lowerWorking.hasPrefix("google ") {
            let query = String(workingText.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .webSearch(query: query)
        }
        
        // Terminal command execution intent (e.g. "run: git status", "exec: ls -la")
        if lower.hasPrefix("run ") || lower.hasPrefix("run: ") || lower.hasPrefix("exec ") {
            let cmd: String
            if lower.hasPrefix("run: ") {
                cmd = String(trimmed.dropFirst(5))
            } else if lower.hasPrefix("run ") {
                cmd = String(trimmed.dropFirst(4))
            } else {
                cmd = String(trimmed.dropFirst(5))
            }
            return .terminalCommand(command: cmd)
        }
        
        // Coding assistance intent
        if lower.contains("error:") || lower.contains("fatal error") || lower.contains("bug") ||
            lower.contains("fix this code") || lower.contains("explain this code") || lower.contains("refactor") {
            return .codingHelp(query: trimmed)
        }
        
        // Default: Chat & reasoning
        return .chat(query: trimmed)
    }
}
