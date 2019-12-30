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
            syncIndexToContinueMO = Int32(newValue)
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

    func setMetaData(fromLibraryChangeDates: LibraryChangeDates) {
        dateOfLastUpdate = fromLibraryChangeDates.dateOfLastUpdate as NSDate
        dateOfLastAdd = fromLibraryChangeDates.dateOfLastAdd as NSDate
        dateOfLastClean = fromLibraryChangeDates.dateOfLastClean as NSDate
    }
    
    var songs: [Song] {
        var returnSongs = [Song]()
        guard let songsMOSet = songsMO, let songsMOArray = songsMOSet.array as? [SongMO] else { return returnSongs }
        for song in songsMOArray {
            returnSongs.append(Song(managedObject: song))
        }
        return returnSongs
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }

}
