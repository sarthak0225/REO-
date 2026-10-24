import Foundation
import Security

/// Production macOS Keychain implementation conforming to CredentialStore
public final class KeychainManager: CredentialStore, @unchecked Sendable {
    public static let shared = KeychainManager()
    
    private init() {}
    
    public func saveCredential(_ secret: String, for service: String, account: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw CredentialError.invalidData
        }
        
        // Remove existing item if present
        try? deleteCredential(for: service, account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialError.failedToSave(status)
        }
        
        AppLogger.shared.info("Credential saved securely for service: \(service), account: \(account)", category: .security)
    }
    
    public func loadCredential(for service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            throw CredentialError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw CredentialError.failedToLoad(status)
        }
        
        guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw CredentialError.invalidData
        }
        
        return secret
    }
    
    public func deleteCredential(for service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.failedToDelete(status)
        }
        
        AppLogger.shared.info("Credential deleted for service: \(service), account: \(account)", category: .security)
    }
    
    public func hasCredential(for service: String, account: String) -> Bool {
        do {
            _ = try loadCredential(for: service, account: account)
            return true
        } catch {
            return false
        }
    }
}

/// In-memory credential store for testing and fallback
public final class MockCredentialStore: CredentialStore, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    private func key(service: String, account: String) -> String {
        "\(service):::\(account)"
    }
    
    public func saveCredential(_ secret: String, for service: String, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key(service: service, account: account)] = secret
    }
    
    public func loadCredential(for service: String, account: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let secret = storage[key(service: service, account: account)] else {
            throw CredentialError.itemNotFound
        }
        return secret
    }
    
    public func deleteCredential(for service: String, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key(service: service, account: account))
    }
    
    public func hasCredential(for service: String, account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key(service: service, account: account)] != nil
    }
}
