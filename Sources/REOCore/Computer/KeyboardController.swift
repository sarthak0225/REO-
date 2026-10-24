import Foundation
import CoreGraphics
import ApplicationServices

public final class KeyboardController: @unchecked Sendable {
    public static let shared = KeyboardController()
    
    private init() {}
    
    public func typeText(_ text: String) async throws -> ActionResult {
        guard AXIsProcessTrusted() else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Accessibility permission is required for typing simulation. Please enable it in Settings."
            )
        }
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        for char in text {
            let utf16Chars = Array(String(char).utf16)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            
            keyDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            keyUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms delay between keystrokes
        }
        
        return ActionResult(success: true, output: "Typed \(text.count) characters.")
    }
    
    public func pressKey(combination: String) async throws -> ActionResult {
        guard AXIsProcessTrusted() else {
            return ActionResult(
                success: false,
                output: "",
                errorDescription: "Accessibility permission is required for keyboard shortcuts."
            )
        }
        
        // Example: "cmd+c", "cmd+v", "enter", "escape"
        let lower = combination.lowercased()
        let source = CGEventSource(stateID: .hidSystemState)
        
        var virtualKey: CGKeyCode = 0
        var flags: CGEventFlags = []
        
        if lower.contains("cmd") || lower.contains("command") {
            flags.insert(.maskCommand)
        }
        if lower.contains("shift") {
            flags.insert(.maskShift)
        }
        if lower.contains("alt") || lower.contains("option") {
            flags.insert(.maskAlternate)
        }
        if lower.contains("ctrl") || lower.contains("control") {
            flags.insert(.maskControl)
        }
        
        if lower.contains("enter") || lower.contains("return") {
            virtualKey = 36
        } else if lower.contains("space") {
            virtualKey = 49
        } else if lower.contains("escape") {
            virtualKey = 53
        } else if lower.contains("tab") {
            virtualKey = 48
        } else if lower.hasSuffix("c") {
            virtualKey = 8
        } else if lower.hasSuffix("v") {
            virtualKey = 9
        } else if lower.hasSuffix("a") {
            virtualKey = 0
        } else if lower.hasSuffix("w") {
            virtualKey = 13
        } else {
            virtualKey = 36 // default return
        }
        
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to construct keyboard event")
        }
        
        down.flags = flags
        up.flags = flags
        
        down.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 20_000_000)
        up.post(tap: .cghidEventTap)
        
        return ActionResult(success: true, output: "Pressed key: \(combination)")
    }
}
