import SwiftUI

public struct InputView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var context: ContextManager = .shared
    @ObservedObject var speech: SpeechRecognizer = .shared
    @ObservedObject var conversation: ConversationEngine = .shared
    
    @FocusState private var isFieldFocused: Bool
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // Attached Screen Context indicator chip
            if context.isScreenContextAttached {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RioTheme.brandGradient)
                    Text("Active Screen Context Attached")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        context.clearScreenContext()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RioTheme.cyan.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(RioTheme.cyan.opacity(0.3), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Seamless Pill Input Bar
            HStack(spacing: 8) {
                // Attach Screen Context button
                Button(action: {
                    appState.triggerScreenCapture()
                }) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 12))
                        .foregroundColor(context.isScreenContextAttached ? RioTheme.cyan : .secondary)
                        .frame(width: 26, height: 26)
                        .background(context.isScreenContextAttached ? RioTheme.cyan.opacity(0.16) : Color.clear)
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Capture and attach current screen context")
                
                // Borderless Text input
                TextField("Ask Rio or dictate a task...", text: $appState.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($isFieldFocused)
                    .onSubmit {
                        appState.submitCurrentInput()
                    }
                
                // Voice microphone button with live state animation
                Button(action: {
                    appState.toggleVoiceInput()
                }) {
                    ZStack {
                        if speech.isListening {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 26, height: 26)
                                .scaleEffect(1.15)
                                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speech.isListening)
                        }
                        
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 12))
                            .foregroundColor(speech.isListening ? .red : .secondary)
                    }
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(speech.isListening ? "Stop listening" : "Speak to Rio")
                
                // Submit or Cancel button
                if conversation.isProcessing {
                    Button(action: {
                        appState.cancelCurrentTask()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Stop current task")
                } else {
                    let hasInput = !appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || context.isScreenContextAttached
                    Button(action: {
                        appState.submitCurrentInput()
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Group {
                                    if hasInput {
                                        RioTheme.brandGradient
                                    } else {
                                        LinearGradient(colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                    }
                                }
                            )
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput)
                    .help("Send (Return)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RioTheme.pillBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isFieldFocused ? RioTheme.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .onAppear {
            isFieldFocused = true
        }
    }
}
