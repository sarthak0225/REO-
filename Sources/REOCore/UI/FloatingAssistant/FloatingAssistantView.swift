import SwiftUI

public struct FloatingAssistantView: View {
    @ObservedObject var appState: AppState = .shared
    @ObservedObject var conversation: ConversationEngine = .shared
    @ObservedObject var executor: ActionExecutor = .shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if !appState.isExpanded {
                CompactPillView()
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            } else {
                expandedPopUpView
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.isExpanded)
        .sheet(isPresented: $appState.isSettingsOpen) {
            SettingsView()
        }
        .sheet(isPresented: $appState.isPermissionViewOpen) {
            PermissionPromptView()
        }
    }
    
    private var expandedPopUpView: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Header: Rio brand, living status, model pill, and controls
                StatusIndicatorView()
                
                // Action approval card if pending
                if executor.pendingAction != nil {
                    ActionApprovalView()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                
                // Conversation Area: Expands smoothly
                ConversationView()
                    .frame(minHeight: 180, maxHeight: 360)
                
                // Footer: Seamless pill search & dictate bar
                InputView()
            }
            
            // Contextual Quick Actions Pop-Up Overlay
            if appState.isQuickActionsOpen {
                QuickActionsPopoverView()
                    .padding(.top, 44)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(width: 450)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                RioTheme.glassCardBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RioTheme.specularRim, lineWidth: 0.85)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 26, x: 0, y: 12)
        .shadow(color: RioTheme.violet.opacity(0.12), radius: 20, x: 0, y: 6)
    }
}

/// AppKit NSVisualEffectView wrapper for SwiftUI
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material = .popover, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
