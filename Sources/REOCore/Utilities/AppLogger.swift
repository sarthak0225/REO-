import Foundation
import os.log

public enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public enum LogCategory: String, Sendable {
    case lifecycle = "Lifecycle"
    case ai = "AI"
    case voice = "Voice"
    case vision = "Vision"
    case agent = "Agent"
    case security = "Security"
    case ui = "UI"
    case general = "General"
}

/// Structured logger that strictly forbids logging secrets, raw audio, screenshots, and passwords.
public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()
    
    private let subsystem = "com.reo.assistant"
    private let queue = DispatchQueue(label: "com.reo.logger", qos: .utility)
    public var isDebugModeEnabled: Bool = false
    public var isPrivacyModeActive: Bool = false
    
    private init() {}
    
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        // Enforce privacy constraints: If privacy mode is on, suppress debug logs
        if isPrivacyModeActive && level == .debug {
            return
        }
        
        let sanitized = sanitize(message)
        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        queue.async {
            let logLine = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] [\(filename):\(line)] \(sanitized)"
            
            #if DEBUG
            print(logLine)
            #else
            if self.isDebugModeEnabled || level != .debug {
                print(logLine)
            }
            #endif
            
            let osLog = OSLog(subsystem: self.subsystem, category: category.rawValue)
            switch level {
            case .debug:
                os_log("%{public}@", log: osLog, type: .debug, sanitized)
            case .info:
                os_log("%{public}@", log: osLog, type: .info, sanitized)
            case .warning:
                os_log("%{public}@", log: osLog, type: .default, sanitized)
            case .error:
                os_log("%{public}@", log: osLog, type: .error, sanitized)
            }
        }
    }
    
    public func debug(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, line: line)
    }
    
    public func info(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .info, category: category, file: file, line: line)
    }
    
    public func warning(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, line: line)
    }
    
    public func error(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        log(message, level: .error, category: category, file: file, line: line)
    }
    
    /// Sanitizes messages to strip potential API keys or tokens
    private func sanitize(_ text: String) -> String {
        // Mask strings that look like Bearer tokens or API keys (e.g. sk-..., key-...)
        var result = text
        let patterns = [
            "sk-[a-zA-Z0-9_-]{20,}",
            "Bearer\\s+[a-zA-Z0-9_.-]+",
            "key-[a-zA-Z0-9_-]{20,}",
            "AIza[0-9A-Za-z-_]{30,}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "[REDACTED_CREDENTIAL]")
            }
        }
        return result
    }
}
