import SwiftUI
import AppKit

public struct ChatMessageView: View {
    public let message: ChatMessage
    @State private var isCopied: Bool = false
    
    public init(message: ChatMessage) {
        self.message = message
    }
    
    public var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 40)
                    userBubble
                } else if message.role == .tool {
                    toolResultBubble
                    Spacer(minLength: 40)
                } else {
                    assistantBubble
                    Spacer(minLength: 40)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 12.5))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                )
        }
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    // Assistant Monogram Header
                    HStack(spacing: 4) {
                        RioSparkleView(size: 10)
                        Text("Rio")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(RioTheme.brandGradient)
                    }
                    .padding(.bottom, 1)
                    
                    if message.content.isEmpty && message.isStreaming {
                        HStack(spacing: 5) {
                            Text("Reasoning")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.secondary)
                            ProgressView()
                                .scaleEffect(0.55)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text(message.content)
                            .font(.system(size: 12.5))
                            .foregroundColor(.primary)
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    }
                    
                    // Code blocks if present
                    let codeBlocks = ResponseParser.shared.extractCodeBlocks(from: message.content)
                    if !codeBlocks.isEmpty {
                        ForEach(codeBlocks) { block in
                            CodeBlockSnippetView(codeBlock: block)
                        }
                    }
                    
                    // Tool calls if present
                    if let calls = message.toolCalls, !calls.isEmpty {
                        ForEach(calls) { call in
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 9))
                                    .foregroundStyle(RioTheme.brandGradient)
                                Text("Action: \(call.name)")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Copy button
                if !message.content.isEmpty {
                    Button(action: {
                        copyToClipboard(message.content)
                    }) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5))
                            .foregroundColor(isCopied ? RioTheme.cyan : .secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Copy message")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private var toolResultBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 10))
            Text(message.content)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(Color.secondary.opacity(0.05))
        .clipShape(Capsule())
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}

public struct CodeBlockSnippetView: View {
    public let codeBlock: CodeBlock
    @State private var isCopied: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(codeBlock.language.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(RioTheme.brandGradient)
                Spacer()
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(codeBlock.code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 9.5))
                    .foregroundColor(isCopied ? RioTheme.cyan : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.2))
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .textSelection(.enabled)
            }
        }
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
