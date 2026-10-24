import SwiftUI

public struct StatusIndicatorView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var privacy: PrivacyManager = .shared
    @ObservedObject var speech: SpeechRecognizer = .shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // Brand & Status
            HStack(spacing: 6) {
                RioSparkleView(size: 13)
                
                Text("Rio")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Status Badge Chip
                HStack(spacing: 4) {
                    if speech.isListening {
                        VoiceWaveformView()
                    } else {
                        Circle()
                            .fill(appState.status.statusDotColor)
                            .frame(width: 5.5, height: 5.5)
                            .scaleEffect(appState.status == .listening || appState.status == .thinking ? 1.3 : 1.0)
                            .animation(
                                appState.status == .listening || appState.status == .thinking
                                ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                : .default,
                                value: appState.status
                            )
                        Text(appState.status.rawValue)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Model Badge
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 8))
                    .foregroundStyle(RioTheme.brandGradient)
                Text(appState.settings.modelName)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.secondary.opacity(0.06))
            .clipShape(Capsule())
            
            // Privacy indicator if on
            if privacy.isPrivacyModeActive {
                HStack(spacing: 3) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 8))
                    Text("Privacy")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .foregroundColor(.primary)
                .clipShape(Capsule())
            }
            
            // Quick Actions Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appState.isQuickActionsOpen.toggle()
                }
            }) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(appState.isQuickActionsOpen ? RioTheme.cyan : .secondary)
                    .frame(width: 22, height: 22)
                    .background(appState.isQuickActionsOpen ? RioTheme.cyan.opacity(0.15) : Color.clear)
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quick Actions")
            
            // Settings button
            Button(action: {
                appState.isSettingsOpen.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
            
            // Collapse to Pill button
            Button(action: {
                appState.collapseToPill()
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Collapse to Floating Pill")
            
            // Close / Hide button
            Button(action: {
                FloatingAssistantPanelManager.shared.hide()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hide Rio (⌘⇧Space)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
