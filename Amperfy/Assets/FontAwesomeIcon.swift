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
    
    var asString: String {
        return String(format: "%C", self.rawValue)
    }
    
    static var fontName: String {
        return "FontAwesome5FreeSolid"
    }
}
