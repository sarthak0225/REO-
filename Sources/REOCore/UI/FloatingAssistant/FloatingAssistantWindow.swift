import Foundation
import AppKit
import SwiftUI

public final class FloatingAssistantPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
public final class FloatingAssistantPanelManager: ObservableObject {
    public static let shared = FloatingAssistantPanelManager()
    
    private var panel: FloatingAssistantPanel?
    private var outsideClickMonitor: Any?
    
    private init() {}
    
    public func createAndShowPanel() {
        if let existing = panel {
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startOutsideClickMonitoring()
            return
        }
        
        let initialWidth: CGFloat = 450
        let initialHeight: CGFloat = 200
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenRect.midX - (initialWidth / 2)
        let y = screenRect.maxY - initialHeight - 120
        
        let newPanel = FloatingAssistantPanel(
            contentRect: NSRect(x: x, y: y, width: initialWidth, height: initialHeight)
        )
        
        let hostingView = NSHostingView(rootView: FloatingAssistantView())
        newPanel.contentView = hostingView
        newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        newPanel.orderFrontRegardless()
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.panel = newPanel
        startOutsideClickMonitoring()
    }
    
    public func startOutsideClickMonitoring() {
        guard outsideClickMonitor == nil else { return }
        
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let panel = self.panel,
                      panel.isVisible else { return }
                
                let mouseLocation = NSEvent.mouseLocation
                
                // Never dismiss if click is inside the panel's boundary
                if panel.frame.contains(mouseLocation) {
                    return
                }
                
                // Do not dismiss when settings or permission sheets are presented
                if AppState.shared.isSettingsOpen || AppState.shared.isPermissionViewOpen {
                    return
                }
                
                // Do not dismiss while voice recording/listening is in progress
                if SpeechRecognizer.shared.isListening {
                    return
                }
                
                // If quick actions popover is open, outside click dismisses quick actions first
                if AppState.shared.isQuickActionsOpen {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        AppState.shared.isQuickActionsOpen = false
                    }
                    return
                }
                
                // Outside-click dismissal: collapse expanded panel to pill
                if AppState.shared.isExpanded {
                    AppState.shared.collapseToPill()
                }
            }
        }
    }
    
    public func stopOutsideClickMonitoring() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
    
    public func toggleVisibility() {
        guard let panel = panel else {
            createAndShowPanel()
            return
        }
        
        if panel.isVisible {
            panel.orderOut(nil)
            AppState.shared.isPanelVisible = false
        } else {
            panel.orderFrontRegardless()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            AppState.shared.isPanelVisible = true
            startOutsideClickMonitoring()
        }
    }
    
    public func hide() {
        panel?.orderOut(nil)
        AppState.shared.isPanelVisible = false
    }
    
    public func show() {
        guard let panel = panel else {
            createAndShowPanel()
            return
        }
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AppState.shared.isPanelVisible = true
        startOutsideClickMonitoring()
    }
    
    public func updateWindowSize(isExpanded: Bool) {
        guard let panel = panel else { return }
        let currentFrame = panel.frame
        
        let targetWidth: CGFloat = isExpanded ? 450 : 250
        let targetHeight: CGFloat = isExpanded ? 450 : 52
        
        let topY = currentFrame.maxY
        let midX = currentFrame.midX
        
        let newX = midX - (targetWidth / 2)
        let newY = topY - targetHeight
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
}
