import Foundation
import AppKit

public struct ScreenContext: Sendable {
    public let timestamp: Date
    public let displayID: CGDirectDisplayID?
    public let activeApplicationName: String?
    public let activeWindowTitle: String?
    public let displayBounds: CGRect?
    public let imageBase64: String?
    public let summary: String
    
    public init(
        timestamp: Date = Date(),
        displayID: CGDirectDisplayID? = nil,
        activeApplicationName: String? = nil,
        activeWindowTitle: String? = nil,
        displayBounds: CGRect? = nil,
        imageBase64: String? = nil,
        summary: String
    ) {
        self.timestamp = timestamp
        self.displayID = displayID
        self.activeApplicationName = activeApplicationName
        self.activeWindowTitle = activeWindowTitle
        self.displayBounds = displayBounds
        self.imageBase64 = imageBase64
        self.summary = summary
    }
}

public protocol ScreenCaptureProvider: Sendable {
    func captureMainDisplay() async throws -> ScreenContext
    func captureActiveWindow() async throws -> ScreenContext
}
