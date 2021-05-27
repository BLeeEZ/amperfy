import Foundation

enum LibrarySyncVersion: Int, Comparable, CustomStringConvertible {
    case v6 = 0
    case v7 = 1 // Genres added
    case v8 = 2 // Directories added
    
    var description : String {
        switch self {
        case .v6: return "v6"
        case .v7: return "v7"
        case .v8: return "v8"
        }
    }
    var isNewestVersion: Bool {
        return self == Self.newestVersion
    }
    
    static let newestVersion: LibrarySyncVersion = .v8
    static let defaultValue: LibrarySyncVersion = .v6
    
    static func < (lhs: LibrarySyncVersion, rhs: LibrarySyncVersion) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
