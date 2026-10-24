import Foundation

public enum REOEvent: Sendable {
    case activationToggled
    case assistantStateChanged(String)
    case taskCancelled
    case permissionStatusUpdated
    case privacyModeToggled(Bool)
    case messageSent(String)
    case quickActionTriggered(String)
}

public final class EventBus: @unchecked Sendable {
    public static let shared = EventBus()
    
    public typealias EventHandler = @Sendable (REOEvent) -> Void
    
    private var subscribers: [UUID: EventHandler] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    @discardableResult
    public func subscribe(_ handler: @escaping EventHandler) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        subscribers[id] = handler
        return id
    }
    
    public func unsubscribe(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        subscribers.removeValue(forKey: id)
    }
    
    public func publish(_ event: REOEvent) {
        lock.lock()
        let currentSubscribers = Array(subscribers.values)
        lock.unlock()
        
        for handler in currentSubscribers {
            handler(event)
        }
    }
}
