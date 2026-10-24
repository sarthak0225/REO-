import Foundation
import SwiftUI

public enum UserActionDecision: Sendable {
    case allowOnce
    case alwaysAllow
    case cancel
}

@MainActor
public final class ActionExecutor: ObservableObject {
    public static let shared = ActionExecutor()
    
    @Published public private(set) var pendingAction: (any Action)? = nil
    @Published public private(set) var pendingReason: String? = nil
    
    private var pendingContinuation: CheckedContinuation<UserActionDecision, Never>? = nil
    
    private init() {}
    
    public func executeAction(
        _ action: any Action,
        settings: SettingsManager = SettingsManager.shared,
        isPrivacyMode: Bool = false
    ) async -> ActionResult {
        let validation = ActionValidator.shared.validate(
            action: action,
            settings: settings,
            isPrivacyModeActive: isPrivacyMode
        )
        
        if validation.requiresUserConfirmation {
            AppLogger.shared.info("Action '\(action.name)' requires user confirmation: \(validation.reason)", category: .agent)
            
            // Present approval UI and wait for user response
            let userDecision = await requestUserApproval(for: action, reason: validation.reason)
            
            switch userDecision {
            case .cancel:
                let result = ActionResult(success: false, output: "", errorDescription: "Action cancelled by user.")
                ActionHistory.shared.record(action: action, result: result)
                return result
                
            case .alwaysAllow:
                // Modify user settings if action is low/medium
                if action.riskLevel == .low {
                    settings.confirmLowRiskActions = false
                } else if action.riskLevel == .medium {
                    settings.confirmMediumRiskActions = false
                }
                fallthrough
                
            case .allowOnce:
                break
            }
        }
        
        do {
            AppLogger.shared.info("Executing action: \(action.name)", category: .agent)
            let result = try await action.execute()
            ActionHistory.shared.record(action: action, result: result)
            return result
        } catch {
            let result = ActionResult(
                success: false,
                output: "",
                errorDescription: "Action failed with error: \(error.localizedDescription)"
            )
            ActionHistory.shared.record(action: action, result: result)
            return result
        }
    }
    
    private func requestUserApproval(for action: any Action, reason: String) async -> UserActionDecision {
        self.pendingAction = action
        self.pendingReason = reason
        
        return await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
        }
    }
    
    public func resolvePendingApproval(with decision: UserActionDecision) {
        let continuation = self.pendingContinuation
        self.pendingContinuation = nil
        self.pendingAction = nil
        self.pendingReason = nil
        continuation?.resume(returning: decision)
    }
}
