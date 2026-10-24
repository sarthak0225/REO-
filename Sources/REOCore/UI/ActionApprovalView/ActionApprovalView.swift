import SwiftUI

public struct ActionApprovalView: View {
    @ObservedObject var executor: ActionExecutor = .shared
    
    public init() {}
    
    public var body: some View {
        if let action = executor.pendingAction {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(action.riskLevel.badgeColor)
                        .font(.system(size: 12))
                    
                    Text("Action Approval Required")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(action.riskLevel.rawValue)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(action.riskLevel.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(action.riskLevel.badgeColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rio wants to execute:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(action.description)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let reason = executor.pendingReason {
                        Text(reason)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Button("Cancel") {
                        executor.resolvePendingApproval(with: .cancel)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    if action.riskLevel != .high {
                        Button("Always Allow") {
                            executor.resolvePendingApproval(with: .alwaysAllow)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Button("Allow Once") {
                        executor.resolvePendingApproval(with: .allowOnce)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.riskLevel.badgeColor)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(action.riskLevel.badgeColor.opacity(0.35), lineWidth: 0.75)
            )
        }
    }
}
