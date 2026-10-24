import Foundation
import AppKit

public final class BrowserController: @unchecked Sendable {
    public static let shared = BrowserController()
    
    private init() {}
    
    public func openURL(_ urlString: String) async throws -> ActionResult {
        var cleanURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURLString.lowercased().hasPrefix("http://") && !cleanURLString.lowercased().hasPrefix("https://") {
            cleanURLString = "https://" + cleanURLString
        }
        
        guard let url = URL(string: cleanURLString) else {
            return ActionResult(success: false, output: "", errorDescription: "Invalid URL: \(urlString)")
        }
        
        let success = NSWorkspace.shared.open(url)
        if success {
            return ActionResult(success: true, output: "Opened URL: \(cleanURLString)")
        } else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to open URL in default browser.")
        }
    }
    
    public func searchWeb(query: String) async throws -> ActionResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?q=\(encoded)") else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to encode search query.")
        }
        
        let success = NSWorkspace.shared.open(url)
        if success {
            return ActionResult(success: true, output: "Launched search for: \"\(query)\"")
        } else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to open web search.")
        }
    }
    
    public func fetchWebpageText(from urlString: String) async throws -> ActionResult {
        guard let url = URL(string: urlString) else {
            return ActionResult(success: false, output: "", errorDescription: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) REO/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return ActionResult(success: false, output: "", errorDescription: "Failed to fetch webpage content")
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        // Strip basic HTML tags
        let plainText = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        let truncated = String(plainText.prefix(2000))
        return ActionResult(success: true, output: truncated)
    }
}
