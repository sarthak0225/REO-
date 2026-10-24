import Foundation
import AppKit

public struct AttachedContext: Sendable {
    public let screenSummary: String?
    public let screenImageBase64: String?
    public let clipboardText: String?
    public let attachedFiles: [AttachedFile]
    
    public init(
        screenSummary: String? = nil,
        screenImageBase64: String? = nil,
        clipboardText: String? = nil,
        attachedFiles: [AttachedFile] = []
    ) {
        self.screenSummary = screenSummary
        self.screenImageBase64 = screenImageBase64
        self.clipboardText = clipboardText
        self.attachedFiles = attachedFiles
    }
}

public struct AttachedFile: Sendable, Identifiable {
    public let id = UUID()
    public let filename: String
    public let content: String
    public let byteSize: Int
    
    public init(filename: String, content: String, byteSize: Int) {
        self.filename = filename
        self.content = content
        self.byteSize = byteSize
    }
}

@MainActor
public final class ContextManager: ObservableObject {
    public static let shared = ContextManager()
    
    @Published public private(set) var pendingScreenImageBase64: String? = nil
    @Published public private(set) var pendingScreenSummary: String? = nil
    @Published public private(set) var pendingFiles: [AttachedFile] = []
    @Published public private(set) var isScreenContextAttached: Bool = false
    
    private init() {}
    
    public func attachScreenContext(summary: String, imageBase64: String?) {
        self.pendingScreenSummary = summary
        self.pendingScreenImageBase64 = imageBase64
        self.isScreenContextAttached = true
        AppLogger.shared.info("Screen context attached (\(summary))", category: .vision)
    }
    
    public func clearScreenContext() {
        self.pendingScreenSummary = nil
        self.pendingScreenImageBase64 = nil
        self.isScreenContextAttached = false
    }
    
    public func attachFile(url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? content.count
        let file = AttachedFile(filename: url.lastPathComponent, content: content, byteSize: size)
        pendingFiles.append(file)
        AppLogger.shared.info("Attached file: \(url.lastPathComponent) (\(size) bytes)", category: .general)
    }
    
    public func removeFile(id: UUID) {
        pendingFiles.removeAll { $0.id == id }
    }
    
    public func clearAllPendingContext() {
        clearScreenContext()
        pendingFiles.removeAll()
    }
    
    /// Reads clipboard content ONLY upon explicit user command
    public func readExplicitClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else {
            return nil
        }
        AppLogger.shared.info("Explicit clipboard read performed", category: .security)
        return text
    }
    
    /// Consumes and returns current pending context, resetting pending state
    public func consumePendingContext() -> AttachedContext {
        let ctx = AttachedContext(
            screenSummary: pendingScreenSummary,
            screenImageBase64: pendingScreenImageBase64,
            clipboardText: nil,
            attachedFiles: pendingFiles
        )
        clearAllPendingContext()
        return ctx
    }
}
