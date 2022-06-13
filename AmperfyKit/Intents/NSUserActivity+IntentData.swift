import Foundation

extension NSUserActivity {
    
    public enum ActivityKeys: String {
        case searchTerm
        case searchCategory
        case shuffleOption
        case repeatOption
        case offlineMode
    }
    
    public static let searchAndPlayActivityType = "de.familie-zimba.Amperfy.SearchAndPlay"

}
