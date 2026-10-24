import SwiftUI

public struct ConversationView: View {
    @ObservedObject var conversation: ConversationEngine = .shared
    @ObservedObject var appState: AppState = .shared
    
    public init() {}
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    if conversation.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(conversation.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastId = conversation.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: conversation.messages.last?.content) { _, _ in
                if let lastId = conversation.messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 12)
            
            // Header Sparkle & Welcome
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    RioSparkleView(size: 16)
                    Text("Rio Assistant")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RioTheme.brandGradient)
                }
                
                Text("Voice-first, screen-aware intelligence on your desktop.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Minimal Pill Suggestion Chips
            VStack(spacing: 6) {
                suggestionButton(title: "What's on my screen?", icon: "camera.viewfinder") {
                    appState.handleUserInput("What's on my screen?")
                }
                
                suggestionButton(title: "Explain code on my display", icon: "curlybraces") {
                    appState.handleUserInput("Help me understand this code")
                }
                
                suggestionButton(title: "Search the web for Swift 6 features", icon: "safari") {
                    appState.handleUserInput("Search for Swift 6 features")
                }
                
                suggestionButton(title: "Dictate a quick note or task", icon: "mic") {
                    appState.toggleVoiceInput()
                }
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 12)
        }
    }
    
    private func suggestionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(RioTheme.brandGradient)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6.5)
            .background(Color.secondary.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
