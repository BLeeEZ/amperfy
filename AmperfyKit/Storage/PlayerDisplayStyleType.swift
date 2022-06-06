import Foundation

public enum PlayerDisplayStyle: Int {
    case compact = 0
    case large = 1
    
    static let defaultValue: PlayerDisplayStyle = .large
    
    public mutating func switchToNextStyle() {
        switch self {
        case .compact:
            self = .large
        case .large:
            self = .compact
        }
    }
    
    public var description : String {
        switch self {
        case .compact: return "Compact"
        case .large: return "Large"
        }
    }
}
