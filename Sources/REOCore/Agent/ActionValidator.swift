import Foundation

public struct ValidationDecision: Sendable {
    public let isAllowedToRunDirectly: Bool
    public let requiresUserConfirmation: Bool
    public let reason: String
}

@MainActor
public final class ActionValidator: Sendable {
    public static let shared = ActionValidator()
    
    private init() {}
    
    public func validate(
        action: any Action,
        settings: SettingsManager = SettingsManager.shared,
        isPrivacyModeActive: Bool = false
    ) -> ValidationDecision {
        // High risk actions ALWAYS require explicit user confirmation
        if action.riskLevel == .high {
            return ValidationDecision(
                isAllowedToRunDirectly: false,
                requiresUserConfirmation: true,
                reason: "High-risk action requires your explicit confirmation."
            )
        }
        
        // Privacy mode elevates confirmation strictness
        if isPrivacyModeActive {
            return ValidationDecision(
                isAllowedToRunDirectly: false,
                requiresUserConfirmation: true,
                reason: "Privacy Mode is active. All actions require manual confirmation."
            )
        }
        
        switch action.riskLevel {
        case .low:
            if settings.confirmLowRiskActions {
                return ValidationDecision(
                    isAllowedToRunDirectly: false,
                    requiresUserConfirmation: true,
                    reason: "Low-risk confirmation is enabled in Settings."
                )
            } else {
                return ValidationDecision(
                    isAllowedToRunDirectly: true,
                    requiresUserConfirmation: false,
                    reason: "Low-risk action allowed to execute automatically."
                )
            }
            
        case .medium:
            if settings.confirmMediumRiskActions {
                return ValidationDecision(
                    isAllowedToRunDirectly: false,
                    requiresUserConfirmation: true,
                    reason: "Medium-risk action requires confirmation."
                )
            } else {
                return ValidationDecision(
                    isAllowedToRunDirectly: true,
                    requiresUserConfirmation: false,
                    reason: "Medium-risk confirmation disabled in Settings."
                )
            }
            
        case .high:
            return ValidationDecision(
                isAllowedToRunDirectly: false,
                requiresUserConfirmation: true,
                reason: "High-risk action always requires confirmation."
            )
        }
    }
}
