import Foundation

class LibraryChangeDates: Comparable {

    var dateOfLastUpdate = Date()
    var dateOfLastAdd = Date()
    var dateOfLastClean = Date()
    
    public static func < (lhs: LibraryChangeDates, rhs: LibraryChangeDates) -> Bool {
        switch lhs.dateOfLastAdd.compare(rhs.dateOfLastAdd) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return true
        }
    }
    
    static func == (lhs: LibraryChangeDates, rhs: LibraryChangeDates) -> Bool {
        return ((lhs.dateOfLastUpdate == rhs.dateOfLastUpdate) && (lhs.dateOfLastAdd == rhs.dateOfLastAdd) && (lhs.dateOfLastClean == rhs.dateOfLastClean))
    }
    
}

class AuthentificationHandshake {
    
    var token: String = ""
    var sessionExpire = Date()
    var reauthenicateTime = Date()
    var libraryChangeDates = LibraryChangeDates()
    var songCount: Int = 0
    var artistCount: Int = 0
    var albumCount: Int = 0
    var genreCount: Int = 0
    var playlistCount: Int = 0
    var podcastCount: Int = 0
    var videoCount: Int = 0

}
