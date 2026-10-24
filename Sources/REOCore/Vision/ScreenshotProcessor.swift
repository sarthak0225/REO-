import Foundation
import AppKit

public final class ScreenshotProcessor: Sendable {
    public static let shared = ScreenshotProcessor()
    
    private init() {}
    
    /// Compresses and encodes an NSImage to a base64 JPEG string for AI vision input
    public func encodeToBase64(image: CGImage, maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.75) -> String? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        
        let scale = min(1.0, maxDimension / max(width, height))
        let targetSize = CGSize(width: width * scale, height: height * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        
        guard let resizedCGImage = context.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: resizedCGImage)
        
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        ) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}
