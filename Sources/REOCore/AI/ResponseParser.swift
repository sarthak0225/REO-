import Foundation

public struct CodeBlock: Sendable, Identifiable {
    public let id = UUID()
    public let language: String
    public let code: String
}

public final class ResponseParser: Sendable {
    public static let shared = ResponseParser()
    
    private init() {}
    
    /// Extracts markdown code blocks from a message
    public func extractCodeBlocks(from text: String) -> [CodeBlock] {
        let pattern = "```([a-zA-Z0-9_-]*)\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language = langRange.location != NSNotFound ? nsString.substring(with: langRange) : "text"
            let code = nsString.substring(with: codeRange)
            return CodeBlock(language: language.isEmpty ? "text" : language, code: code)
        }
    }
    
    /// Parses JSON or XML tool calls embedded inside model responses as a fallback
    public func parseEmbeddedToolCalls(from text: String) -> [ToolCall] {
        var results: [ToolCall] = []
        
        // Pattern 1: <tool_call name="...">{"arg": "val"}</tool_call>
        let tagPattern = "<tool_call\\s+name=[\"']([^\"']+)[\"']>([\\s\\S]*?)</tool_call>"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
            let ns = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let name = ns.substring(with: m.range(at: 1))
                let args = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(ToolCall(name: name, arguments: args))
            }
        }
        
        return results
    }
}
