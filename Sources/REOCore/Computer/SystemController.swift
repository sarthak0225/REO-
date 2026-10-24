import Foundation

public final class SystemController: @unchecked Sendable {
    public static let shared = SystemController()
    
    // Explicit blacklist of destructive commands that should never run automatically
    private let blockedCommands = [
        "rm -rf /",
        ":(){ :|:& };:",
        "mkfs",
        "diskutil eraseDisk",
        "shutdown",
        "reboot"
    ]
    
    private init() {}
    
    public func isCommandSafe(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for blocked in blockedCommands {
            if trimmed.contains(blocked) {
                return false
            }
        }
        return true
    }
    
    public func runCommand(_ command: String, timeout: TimeInterval = 15.0) async throws -> ActionResult {
        guard isCommandSafe(command) else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Command was blocked because it poses severe security risk to your system."
            )
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            return ActionResult(success: false, output: "", errorDescription: "Failed to spawn process: \(error.localizedDescription)")
        }
        
        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        if process.isRunning {
            process.terminate()
            return ActionResult(success: false, output: "", errorDescription: "Command timed out after \(Int(timeout)) seconds.")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        let errorString = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus == 0 {
            let combined = outputString.trimmingCharacters(in: .whitespacesAndNewlines)
            return ActionResult(success: true, output: combined.isEmpty ? "Done (exit code 0)" : combined)
        } else {
            let combinedErr = (!errorString.isEmpty ? errorString : outputString).trimmingCharacters(in: .whitespacesAndNewlines)
            return ActionResult(
                success: false,
                output: outputString,
                errorDescription: "Exit code \(process.terminationStatus): \(combinedErr)"
            )
        }
    }
}
