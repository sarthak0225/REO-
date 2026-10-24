import SwiftUI

/// Compact Floating Rio Assistant Pill (Inspired by HeyClicky)
public struct CompactPillView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var speech: SpeechRecognizer = .shared
    @ObservedObject var context: ContextManager = .shared
    @ObservedObject var tts: TextToSpeech = .shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // Brand & Sparkle
            HStack(spacing: 5) {
                RioSparkleView(size: 13)
                
                Text("Rio")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.expandPanel()
            }
            
            // Dynamic Middle Status / Soundwave
            HStack(spacing: 5) {
                if speech.isListening {
                    VoiceWaveformView()
                } else if appState.status == .thinking {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(RioTheme.brandGradient)
                            .frame(width: 5, height: 5)
                            .scaleEffect(1.2)
                            .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: appState.status)
                        Text("Thinking...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else if tts.isSpeaking {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                            .foregroundColor(RioTheme.cyan)
                        Text("Speaking")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.status.statusDotColor)
                            .frame(width: 5, height: 5)
                        Text(appState.status.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 58)
            .contentShape(Rectangle())
            .onTapGesture {
                appState.expandPanel()
            }
            
            Spacer(minLength: 2)
            
            // Micro action buttons
            HStack(spacing: 4) {
                // Screen Vision button
                Button(action: {
                    appState.triggerScreenCapture()
                }) {
                    Image(systemName: context.isScreenContextAttached ? "camera.viewfinder" : "camera.viewfinder")
                        .font(.system(size: 11))
                        .foregroundColor(context.isScreenContextAttached ? RioTheme.cyan : .secondary)
                        .frame(width: 24, height: 24)
                        .background(context.isScreenContextAttached ? RioTheme.cyan.opacity(0.18) : Color.clear)
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Capture screen context")
                
                // Voice Mic button
                Button(action: {
                    appState.toggleVoiceInput()
                }) {
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 11))
                        .foregroundColor(speech.isListening ? .red : .secondary)
                        .frame(width: 24, height: 24)
                        .background(speech.isListening ? Color.red.opacity(0.18) : Color.clear)
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(speech.isListening ? "Stop listening" : "Speak to Rio")
                
                // Expand Pop-up Button
                Button(action: {
                    appState.expandPanel()
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Expand Rio")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 250, height: 48)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                RioTheme.glassCardBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RioTheme.specularRim, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
        .shadow(color: RioTheme.violet.opacity(0.12), radius: 14, x: 0, y: 4)
    }
}
