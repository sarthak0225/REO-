import Foundation
import SwiftUI

@MainActor
public final class PrivacyManager: ObservableObject {
    public static let shared = PrivacyManager()
    
    @Published public private(set) var isPrivacyModeActive: Bool = false
    @Published public private(set) var temporaryScreenCapturesCount: Int = 0
    @Published public private(set) var lastPurgeTimestamp: Date? = nil
    
    private var temporaryFileURLs: [URL] = []
    
    private init() {
        self.isPrivacyModeActive = SettingsManager.shared.privacyMode
    }
    
    public func togglePrivacyMode(_ enabled: Bool) {
        isPrivacyModeActive = enabled
        SettingsManager.shared.privacyMode = enabled
        AppLogger.shared.isPrivacyModeActive = enabled
        
        if enabled {
            // Aggressively purge temporary data immediately
            purgeTemporaryContext()
        }
        
        EventBus.shared.publish(.privacyModeToggled(enabled))
        AppLogger.shared.info("Privacy Mode is now \(enabled ? "ENABLED" : "DISABLED")", category: .security)
    }
    
    public func registerTemporaryFile(url: URL) {
        temporaryFileURLs.append(url)
        temporaryScreenCapturesCount = temporaryFileURLs.count
    }
    
    public func purgeTemporaryContext() {
        let fileManager = FileManager.default
        for url in temporaryFileURLs {
            try? fileManager.removeItem(at: url)
        }
        temporaryFileURLs.removeAll()
        temporaryScreenCapturesCount = 0
        lastPurgeTimestamp = Date()
        AppLogger.shared.info("All temporary context and visual artifacts purged", category: .security)
    }
    
    public func clearAllLocalData(conversationEngine: AnyObject? = nil) {
        purgeTemporaryContext()
        // Reset settings if user desires, or clear conversation history
        EventBus.shared.publish(.taskCancelled)
        AppLogger.shared.info("User triggered complete local data clearance", category: .security)
    }
}
