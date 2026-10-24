import Foundation

public final class SecureStorage: @unchecked Sendable {
    public static let shared = SecureStorage()
    
    private let credentialStore: CredentialStore
    private let serviceName = "com.reo.assistant.credentials"
    
    public init(credentialStore: CredentialStore = KeychainManager.shared) {
        self.credentialStore = credentialStore
    }
    
    public func saveAPIKey(_ key: String, for provider: AIProviderType) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteAPIKey(for: provider)
            return
        }
        try credentialStore.saveCredential(trimmed, for: serviceName, account: provider.rawValue)
        AppLogger.shared.info("Saved API key for \(provider.rawValue)", category: .security)
    }
    
    public func getAPIKey(for provider: AIProviderType) -> String? {
        do {
            let key = try credentialStore.loadCredential(for: serviceName, account: provider.rawValue)
            if !key.isEmpty {
                return key
            }
        } catch {
            // Continue to environment fallback
        }
        
        switch provider {
        case .gemini:
            return EnvLoader.shared.get("GEMINI_API_KEY")
        case .openAI:
            return EnvLoader.shared.get("OPENAI_API_KEY")
        case .anthropic:
            return EnvLoader.shared.get("ANTHROPIC_API_KEY")
        default:
            return nil
        }
    }
    
    public func deleteAPIKey(for provider: AIProviderType) throws {
        try credentialStore.deleteCredential(for: serviceName, account: provider.rawValue)
        AppLogger.shared.info("Deleted API key for \(provider.rawValue)", category: .security)
    }
    
    public func hasAPIKey(for provider: AIProviderType) -> Bool {
        if credentialStore.hasCredential(for: serviceName, account: provider.rawValue) {
            return true
        }
        return getAPIKey(for: provider) != nil
    }
    
    public static func maskKey(_ key: String) -> String {
        guard key.count > 8 else {
            return String(repeating: "•", count: max(4, key.count))
        }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
}
