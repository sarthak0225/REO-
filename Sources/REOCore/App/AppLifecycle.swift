import Foundation
import AppKit

@MainActor
public final class AppLifecycle: NSObject, NSApplicationDelegate {
    public static let shared = AppLifecycle()
    
    private var statusItem: NSStatusItem?
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        EnvLoader.shared.reload()
        AppState.shared.configureSubsystems()
        setupApplicationIcon()
        AppLogger.shared.info("REO application did finish launching", category: .lifecycle)
        setupStatusItem()
        setupGlobalShortcut()
    }
    
    private func setupApplicationIcon() {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = image
        } else if let fallbackImage = NSImage(contentsOfFile: "/Users/sarthakgunti/REO/Resources/AppIcon_1024.png") {
            NSApp.applicationIconImage = fallbackImage
        }
    }
    
    public func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.title = "✦ Rio"
        button.action = #selector(statusItemClicked)
        button.target = self
    }
    
    @objc private func statusItemClicked() {
        AppState.shared.togglePanelVisibility()
    }
    
    private func setupGlobalShortcut() {
        GlobalShortcutManager.shared.startMonitoring {
            Task { @MainActor in
                AppState.shared.togglePanelVisibility()
            }
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.info("REO application will terminate", category: .lifecycle)
        GlobalShortcutManager.shared.stopMonitoring()
        if SettingsManager.shared.privacyMode || SettingsManager.shared.conversationRetention == .ephemeral {
            PrivacyManager.shared.purgeTemporaryContext()
        }
    }
}
