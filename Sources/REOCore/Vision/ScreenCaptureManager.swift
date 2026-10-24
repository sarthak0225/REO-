import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

public enum ScreenCaptureError: LocalizedError, Sendable {
    case permissionDenied
    case noDisplayFound
    case captureFailed(String)
    case privacyModeActive
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required for REO to view your screen. Please grant access in System Settings."
        case .noDisplayFound:
            return "No active display was detected."
        case .captureFailed(let msg):
            return "Failed to capture screen: \(msg)"
        case .privacyModeActive:
            return "Screen capture is disabled while Privacy Mode is active."
        }
    }
}

@MainActor
public final class ScreenCaptureManager: ObservableObject, ScreenCaptureProvider {
    public static let shared = ScreenCaptureManager()
    
    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var lastCaptureContext: ScreenContext? = nil
    
    private init() {}
    
    public func captureMainDisplay() async throws -> ScreenContext {
        if SettingsManager.shared.privacyMode {
            throw ScreenCaptureError.privacyModeActive
        }
        
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw ScreenCaptureError.permissionDenied
        }
        
        isCapturing = true
        defer { isCapturing = false }
        
        let mainDisplayID = CGMainDisplayID()
        let bounds = CGDisplayBounds(mainDisplayID)
        
        // Active app name
        let activeApp = NSWorkspace.shared.frontmostApplication
        let activeAppName = activeApp?.localizedName ?? "Unknown App"
        
        // Try ScreenCaptureKit screenshot if available
        if #available(macOS 14.0, *) {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                    throw ScreenCaptureError.noDisplayFound
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(bounds.width)
                config.height = Int(bounds.height)
                config.showsCursor = false
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let base64 = ScreenshotProcessor.shared.encodeToBase64(image: cgImage)
                
                let context = ScreenContext(
                    displayID: mainDisplayID,
                    activeApplicationName: activeAppName,
                    activeWindowTitle: activeAppName,
                    displayBounds: bounds,
                    imageBase64: base64,
                    summary: "Display #\(mainDisplayID) (Active: \(activeAppName))"
                )
                self.lastCaptureContext = context
                return context
            } catch {
                AppLogger.shared.warning("ScreenCaptureKit capture fallback to CGWindowList: \(error.localizedDescription)", category: .vision)
            }
        }
        
        // CGWindowList fallback
        guard let cgImage = CGWindowListCreateImage(
            bounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            throw ScreenCaptureError.captureFailed("Failed to generate screen image")
        }
        
        let base64 = ScreenshotProcessor.shared.encodeToBase64(image: cgImage)
        let context = ScreenContext(
            displayID: mainDisplayID,
            activeApplicationName: activeAppName,
            activeWindowTitle: activeAppName,
            displayBounds: bounds,
            imageBase64: base64,
            summary: "Display #\(mainDisplayID) (Active: \(activeAppName))"
        )
        self.lastCaptureContext = context
        return context
    }
    
    public func captureActiveWindow() async throws -> ScreenContext {
        // Fallback to main display with frontmost app context
        return try await captureMainDisplay()
    }
}
