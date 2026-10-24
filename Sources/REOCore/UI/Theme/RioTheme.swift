import SwiftUI

/// Shared Design System & Tokens for Rio (Inspired by HeyClicky)
public struct RioTheme {
    // MARK: - Brand Gradients & Colors
    public static let cyan = Color(red: 0.22, green: 0.74, blue: 0.99)
    public static let violet = Color(red: 0.65, green: 0.45, blue: 0.98)
    public static let deepNavy = Color(red: 0.05, green: 0.06, blue: 0.11)
    
    public static let brandGradient = LinearGradient(
        colors: [cyan, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let specularRim = LinearGradient(
        colors: [
            Color.white.opacity(0.35),
            Color.white.opacity(0.10),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let pillBackground = Color.secondary.opacity(0.08)
    public static let glassCardBackground = Color(NSColor.windowBackgroundColor).opacity(0.68)
}

/// Dynamic Audio Waveform Equalizer for Rio's Voice States
public struct VoiceWaveformView: View {
    @ObservedObject var speech: SpeechRecognizer = .shared
    public var activeColor: Color = RioTheme.cyan
    
    public init(activeColor: Color = RioTheme.cyan) {
        self.activeColor = activeColor
    }
    
    public var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(RioTheme.brandGradient)
                    .frame(width: 2.5, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.14), value: speech.audioLevel)
            }
        }
        .frame(height: 14)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 3.5
        let level = CGFloat(speech.audioLevel)
        let multipliers: [CGFloat] = [0.8, 1.4, 1.1, 0.7]
        let variation = sin(Double(index) * 1.5) * 1.5
        return max(base, min(14.0, base + level * 10.0 * multipliers[index % 4] + CGFloat(variation)))
    }
}

/// Rio Sparkle Living Avatar (✦)
public struct RioSparkleView: View {
    public var size: CGFloat = 14
    @ObservedObject var appState: AppState = .shared
    
    public init(size: CGFloat = 14) {
        self.size = size
    }
    
    public var body: some View {
        Text("✦")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(RioTheme.brandGradient)
            .shadow(color: RioTheme.cyan.opacity(0.45), radius: 4)
            .scaleEffect(appState.status == .thinking || appState.status == .listening ? 1.2 : 1.0)
            .rotationEffect(.degrees(appState.status == .thinking ? 360 : 0))
            .animation(
                appState.status == .thinking
                ? Animation.linear(duration: 2.5).repeatForever(autoreverses: false)
                : (appState.status == .listening
                   ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                   : .default),
                value: appState.status
            )
    }
}
