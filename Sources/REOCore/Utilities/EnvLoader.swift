import Foundation

/// Loads environment variables from local .env files securely on macOS.
public final class EnvLoader: @unchecked Sendable {
    public static let shared = EnvLoader()
    
    private var envVariables: [String: String] = [:]
    private let lock = NSLock()
    
    private init() {
        loadDotEnv()
    }
    
    /// Reads a key from loaded .env variables, falling back to process environment.
    public func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        if let val = ProcessInfo.processInfo.environment[key], !val.isEmpty {
            return val
        }
        return envVariables[key]
    }
    
    /// Reloads .env from disk.
    public func reload() {
        lock.lock()
        defer { lock.unlock() }
        loadDotEnv()
    }
    
    private func loadDotEnv() {
        let potentialPaths = candidateDotEnvPaths()
        
        for path in potentialPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            
            parseAndApply(content: content)
            AppLogger.shared.info("Loaded environment configuration from: \(path)", category: .lifecycle)
            break
        }
    }
    
    private func candidateDotEnvPaths() -> [String] {
        var paths: [String] = []
        
        // 1. Current working directory
        let cwd = FileManager.default.currentDirectoryPath
        paths.append("\(cwd)/.env")
        
        // 2. Project source directory
        let projectDir = "/Users/sarthakgunti/REO"
        paths.append("\(projectDir)/.env")
        
        // 3. Application bundle parent traversal
        if let bundlePath = Bundle.main.bundleURL.path as String? {
            var url = URL(fileURLWithPath: bundlePath)
            for _ in 0..<4 {
                url = url.deletingLastPathComponent()
                paths.append(url.appendingPathComponent(".env").path)
            }
        }
        
        // 4. User configuration directory ~/.reo/.env
        let home = NSHomeDirectory()
        paths.append("\(home)/.reo/.env")
        
        return paths
    }
    
    private func parseAndApply(content: String) {
        let lines = content.components(separatedBy: .newlines)
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty && !line.hasPrefix("#") else { continue }
            
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            
            // Strip surrounding quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            
            guard !key.isEmpty else { continue }
            envVariables[key] = value
            
            // Set in process environment if not already defined
            if getenv(key) == nil {
                setenv(key, value, 0)
            }
        }
    }
}
