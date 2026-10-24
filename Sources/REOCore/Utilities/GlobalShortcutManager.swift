import Foundation
import AppKit
import Carbon

@MainActor
public final class GlobalShortcutManager: ObservableObject {
    public static let shared = GlobalShortcutManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onTrigger: (@Sendable () -> Void)?
    
    private init() {}
    
    public func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        self.onTrigger = onTrigger
        stopMonitoring()
        
        // Local monitor (when app is frontmost or focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isTargetShortcut(event) == true {
                onTrigger()
                return nil // consume event
            }
            return event
        }
        
        // Global monitor (when another application has focus)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isTargetShortcut(event) == true {
                Task { @MainActor in
                    onTrigger()
                }
            }
        }
        
        AppLogger.shared.info("Global shortcut monitors initialized for Command+Shift+Space", category: .lifecycle)
    }
    
    public func stopMonitoring() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }
    
    private func isTargetShortcut(_ event: NSEvent) -> Bool {
        // Default target: Command + Shift + Space
        // Space keyCode = 49
        let isSpace = event.keyCode == 49
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        
        return isSpace && hasCmd && hasShift
    }
}
