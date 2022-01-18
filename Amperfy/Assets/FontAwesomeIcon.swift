import Foundation

enum FontAwesomeIcon: Int {
    
    case Play = 0xf04b
    case Pause = 0xf04c
    case VolumeUp = 0xf028
    case Cloud = 0xf0c2
    case Redo = 0xf01e
    case Check = 0xf00c
    case Bars = 0xf0c9
    case SortDown = 0xf0dd
    case Exclamation = 0xf12a
    case Sync = 0xf021
    case Info = 0xf129
    case Podcast = 0xf2ce
    case Ban = 0xf05e
    case Bell = 0xf0f3
    case Star = 0xf005
    
    var asString: String {
        return String(format: "%C", self.rawValue)
    }
    
    static var fontNameRegular: String {
        return "FontAwesome5Free-Regular"
    }
    static var fontNameSolid: String {
        return "FontAwesome5FreeSolid"
    }
    static var fontName: String {
        return "FontAwesome5FreeSolid"
    }
}
