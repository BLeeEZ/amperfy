import Foundation
import CoreData

enum SyncState: Int {
    
    case Artists
    case Albums
    case Songs
    case Done
    
}

@objc(SyncWaveMO)
public class SyncWaveMO: NSManagedObject {

    var syncState: SyncState {
        get {
            return SyncState(rawValue: Int(syncStateMO)) ?? .Artists
        }
        set {
            syncIndexToContinue = 0
            syncStateMO = Int16(newValue.rawValue)
        }
    }
    var syncIndexToContinue: Int {
        get {
            return Int(syncIndexToContinueMO)
        }
        set {
            syncIndexToContinueMO = Int16(newValue)
        }
    }
    var isInitialWave: Bool {
        return id == 0
    }
    var isDone: Bool {
        return syncState == .Done
    }
    
    var libraryChangeDates: LibraryChangeDates {
        let temp = LibraryChangeDates()
        temp.dateOfLastUpdate = dateOfLastUpdate as Date? ?? Date()
        temp.dateOfLastAdd = dateOfLastAdd as Date? ?? Date()
        temp.dateOfLastClean = dateOfLastClean as Date? ?? Date()
        return temp
    }

    func setMetaData(fromAuth: AuthentificationHandshake) {
        dateOfLastUpdate = fromAuth.libraryChangeDates.dateOfLastUpdate as NSDate
        dateOfLastAdd = fromAuth.libraryChangeDates.dateOfLastAdd as NSDate
        dateOfLastClean = fromAuth.libraryChangeDates.dateOfLastClean as NSDate
    }
    
    var songs: [Song] {
        guard let songsSet = songsMO else { return [Song]() }
        return songsSet.array as! [Song]
    }
    
    var hasCachedSongs: Bool {
        for song in songs {
            if song.data != nil {
                return true
            }
        }
        return false
    }

}
