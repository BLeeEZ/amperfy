import Foundation

extension NSUserActivity {
    
    public enum ActivityKeys: String {
        case searchTerm
        case searchCategory
        case shuffleOption
        case repeatOption
    }
    
    public static let searchAndPlayActivityType = "de.familie-zimba.Amperfy.SearchAndPlay"

}
