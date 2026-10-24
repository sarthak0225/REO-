import Foundation
import CoreGraphics
import ApplicationServices

public final class MouseController: @unchecked Sendable {
    public static let shared = MouseController()
    
    private init() {}
    
    public func moveCursor(toX x: Double, y: Double) async throws -> ActionResult {
        guard AXIsProcessTrusted() else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Accessibility permission is required for mouse control."
            )
        }
        
        let point = CGPoint(x: x, y: y)
        guard let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to construct mouse move event.")
        }
        
        moveEvent.post(tap: .cghidEventTap)
        return ActionResult(success: true, output: "Moved cursor to (\(Int(x)), \(Int(y))).")
    }
    
    public func click(x: Double, y: Double) async throws -> ActionResult {
        guard AXIsProcessTrusted() else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Accessibility permission is required for mouse control."
            )
        }
        
        let point = CGPoint(x: x, y: y)
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to construct mouse click event.")
        }
        
        down.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 30_000_000) // 30ms click duration
        up.post(tap: .cghidEventTap)
        
        return ActionResult(success: true, output: "Clicked mouse at (\(Int(x)), \(Int(y))).")
    }
}
