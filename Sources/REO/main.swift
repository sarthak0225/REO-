import AppKit
import SwiftUI
import REOCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.info("REO starting up...", category: .lifecycle)
        AppLifecycle.shared.applicationDidFinishLaunching(notification)
        
        // Show the native floating assistant panel
        FloatingAssistantPanelManager.shared.createAndShowPanel()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingAssistantPanelManager.shared.show()
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppLifecycle.shared.applicationWillTerminate(notification)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
