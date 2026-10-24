import Foundation
import AppKit
import UniformTypeIdentifiers

public final class FileContextProvider: @unchecked Sendable {
    public static let shared = FileContextProvider()
    
    private let supportedExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "csv", "swift", "py", "js", "ts",
        "html", "css", "yaml", "yml", "xml", "sh", "zsh", "c", "cpp", "h"
    ]
    
    private init() {}
    
    public func isExtensionSupported(_ ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }
    
    @MainActor
    public func presentOpenPanel() -> [URL] {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.title = "Select files for REO analysis"
        
        let response = openPanel.runModal()
        guard response == .OK else { return [] }
        return openPanel.urls
    }
    
    public func loadFileContent(from url: URL, maxBytes: Int = 100_000) throws -> String {
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        guard fileData.count <= maxBytes else {
            let truncatedData = fileData.prefix(maxBytes)
            let partial = String(decoding: truncatedData, as: UTF8.self)
            return "\(partial)\n\n[Content truncated by REO: file exceeded \(maxBytes / 1024) KB]"
        }
        
        guard let content = String(data: fileData, encoding: .utf8) else {
            throw NSError(domain: "com.reo.file", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not encoded in UTF-8 text."])
        }
        return content
    }
}
