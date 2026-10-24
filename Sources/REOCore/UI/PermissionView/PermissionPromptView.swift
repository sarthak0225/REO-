import SwiftUI

public struct PermissionPromptView: View {
    @ObservedObject var permissionManager: PermissionManager = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("System Permissions")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Refresh") {
                    permissionManager.checkAllPermissions()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
            }
            
            Text("REO operates with strict privacy controls. Permissions are only utilized upon your explicit command.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(spacing: 10) {
                permissionRow(for: .accessibility, status: permissionManager.accessibilityStatus)
                permissionRow(for: .screenRecording, status: permissionManager.screenRecordingStatus)
                permissionRow(for: .microphone, status: permissionManager.microphoneStatus)
                permissionRow(for: .speechRecognition, status: permissionManager.speechRecognitionStatus)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    private func permissionRow(for type: PermissionType, status: PermissionStatus) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: type))
                .font(.system(size: 14))
                .foregroundColor(status == .granted ? .green : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    statusBadge(for: status)
                }
                
                Text(type.descriptionText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if status != .granted {
                    Button("Open System Settings") {
                        permissionManager.openSettings(for: type)
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
                    .padding(.top, 2)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
    
    private func iconName(for type: PermissionType) -> String {
        switch type {
        case .accessibility: return "hand.tap"
        case .screenRecording: return "macwindow.on.rectangle"
        case .microphone: return "mic"
        case .speechRecognition: return "waveform"
        }
    }
    
    private func statusBadge(for status: PermissionStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(status == .granted ? .green : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((status == .granted ? Color.green : Color.orange).opacity(0.12))
            .clipShape(Capsule())
    }
}
