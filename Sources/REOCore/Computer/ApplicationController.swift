import Foundation
import AppKit

public final class ApplicationController: @unchecked Sendable {
    public static let shared = ApplicationController()
    
    private init() {}
    
    public func openApplication(named name: String) async throws -> ActionResult {
        let workspace = NSWorkspace.shared
        
        // Find application URL by name
        if let appURL = workspace.urlForApplication(withBundleIdentifier: name) ??
            workspace.urlsForApplications(toOpen: URL(fileURLWithPath: "/")).first(where: {
                $0.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(name)
            }) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            do {
                _ = try await workspace.openApplication(at: appURL, configuration: config)
                return ActionResult(success: true, output: "Successfully opened \(name)")
            } catch {
                return ActionResult(success: false, output: "", errorDescription: "Failed to open \(name): \(error.localizedDescription)")
            }
        }
        
        // Fallback: try open command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            return ActionResult(success: true, output: "Launched \(name)")
        } else {
            return ActionResult(success: false, output: "", errorDescription: "Could not locate application named '\(name)'")
        }
    }
    
    public func switchToApplication(named name: String) async throws -> ActionResult {
        let apps = NSWorkspace.shared.runningApplications
        if let match = apps.first(where: { $0.localizedName?.localizedCaseInsensitiveContains(name) == true }) {
            match.activate(options: [.activateIgnoringOtherApps])
            return ActionResult(success: true, output: "Switched to \(match.localizedName ?? name)")
        }
        return ActionResult(success: false, output: "", errorDescription: "Application '\(name)' is not currently running.")
    }
}
