import Foundation

enum FontAwesomeIcon: Int {
    
    case Play = 0xf04b
    case Pause = 0xf04c
    case VolumeUp = 0xf028
    case Cloud = 0xf0c2
    case Redo = 0xf01e
    case Check = 0xf00c
    
    var asString: String {
        return String(format: "%C", self.rawValue)
    }
    
    var fontName: String {
        return "FontAwesome5FreeSolid"
    }
}
