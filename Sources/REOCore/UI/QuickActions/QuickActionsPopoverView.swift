import SwiftUI

public struct QuickActionsPopoverView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var privacy: PrivacyManager = .shared
    @ObservedObject var conversation: ConversationEngine = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("✦ Quick Actions")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RioTheme.brandGradient)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        appState.isQuickActionsOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 4) {
                actionRow(
                    icon: "camera.viewfinder",
                    title: "Inspect Active Screen",
                    subtitle: "Analyze currently focused window"
                ) {
                    appState.triggerScreenCapture()
                    close()
                }
                
                actionRow(
                    icon: "mic.fill",
                    title: "Voice Conversation",
                    subtitle: "Dictate with live transcription"
                ) {
                    close()
                    appState.toggleVoiceInput()
                }
                
                actionRow(
                    icon: "arrow.counterclockwise",
                    title: "Clear Conversation",
                    subtitle: "Reset context and chat history"
                ) {
                    conversation.clearConversation()
                    AppState.shared.context.clearAllPendingContext()
                    AppState.shared.setStatus(.idle, message: "Conversation reset.")
                    close()
                }
                
                actionRow(
                    icon: privacy.isPrivacyModeActive ? "lock.shield.fill" : "lock.shield",
                    title: privacy.isPrivacyModeActive ? "Privacy Mode: ON" : "Privacy Mode: OFF",
                    subtitle: "Toggle ephemeral strict memory mode"
                ) {
                    appState.settings.privacyMode.toggle()
                    close()
                }
                
                actionRow(
                    icon: "gearshape.fill",
                    title: "Rio Settings",
                    subtitle: "Models, audio voice, and shortcuts"
                ) {
                    close()
                    appState.isSettingsOpen = true
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.85)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RioTheme.specularRim, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        .frame(maxWidth: .infinity)
    }
    
    private func close() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            appState.isQuickActionsOpen = false
        }
    }
    
    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(RioTheme.brandGradient)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
