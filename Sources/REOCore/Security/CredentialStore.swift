import Foundation

public enum CredentialError: LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case failedToSave(Int32)
    case failedToLoad(Int32)
    case failedToDelete(Int32)
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Requested credential was not found in secure storage."
        case .duplicateItem:
            return "A credential with this key already exists."
        case .failedToSave(let status):
            return "Unable to save credential securely (OSStatus \(status))."
        case .failedToLoad(let status):
            return "Unable to retrieve credential securely (OSStatus \(status))."
        case .failedToDelete(let status):
            return "Unable to delete credential (OSStatus \(status))."
        case .invalidData:
            return "Credential data could not be decoded."
        }
    }
}

public protocol CredentialStore: Sendable {
    func saveCredential(_ secret: String, for service: String, account: String) throws
    func loadCredential(for service: String, account: String) throws -> String
    func deleteCredential(for service: String, account: String) throws
    func hasCredential(for service: String, account: String) -> Bool
}
