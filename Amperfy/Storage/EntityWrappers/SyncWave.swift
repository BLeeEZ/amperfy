import Foundation
import CoreData

enum SyncState: Int {
    case Artists
    case Albums
    case Songs
    case Done
}

public class SyncWave: NSObject {
    
    let managedObject: SyncWaveMO

    init(managedObject: SyncWaveMO) {
        self.managedObject = managedObject
    }
    
    var id: Int {
        get { return Int(managedObject.id) }
        set { managedObject.id = Int16(newValue) }
    }
    var syncState: SyncState {
        get {
            return SyncState(rawValue: Int(managedObject.syncState)) ?? .Artists
        }
        set {
            syncIndexToContinue = 0
            managedObject.syncState = Int16(newValue.rawValue)
        }
    }
    var syncIndexToContinue: Int {
        get {
            return Int(managedObject.syncIndexToContinue)
        }
        set {
            managedObject.syncIndexToContinue = Int32(newValue)
        }
    }
    var isInitialWave: Bool {
        return managedObject.id == 0
    }
    var isDone: Bool {
        return syncState == .Done
    }
    
    var libraryChangeDates: LibraryChangeDates {
        let temp = LibraryChangeDates()
        temp.dateOfLastUpdate = managedObject.dateOfLastUpdate as Date? ?? Date()
        temp.dateOfLastAdd = managedObject.dateOfLastAdd as Date? ?? Date()
        temp.dateOfLastClean = managedObject.dateOfLastClean as Date? ?? Date()
        return temp
    }

    func setMetaData(fromLibraryChangeDates: LibraryChangeDates) {
        managedObject.dateOfLastUpdate = fromLibraryChangeDates.dateOfLastUpdate as NSDate
        managedObject.dateOfLastAdd = fromLibraryChangeDates.dateOfLastAdd as NSDate
        managedObject.dateOfLastClean = fromLibraryChangeDates.dateOfLastClean as NSDate
    }
    
    var songs: [Song] {
        var returnSongs = [Song]()
        guard let songsMOSet = managedObject.songs, let songsMOArray = songsMOSet.array as? [SongMO] else { return returnSongs }
        for song in songsMOArray {
            returnSongs.append(Song(managedObject: song))
        }
        return returnSongs
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
}
