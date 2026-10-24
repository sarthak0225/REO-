import Foundation
import SwiftUI

public enum ActionRiskLevel: String, Codable, Sendable, Comparable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    
    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
    
    public static func < (lhs: ActionRiskLevel, rhs: ActionRiskLevel) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
    
    public var badgeColor: Color {
        switch self {
        case .low: return Color.green
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }
}
