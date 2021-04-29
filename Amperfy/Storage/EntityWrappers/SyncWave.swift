import Foundation
import CoreData

enum SyncState: Int {
    case Artists
    case Albums
    case Songs
    case Done
}

enum SyncType: Int {
    case newEntries = 0
    case versionResync = 1
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
            syncIndexToContinue = ""
            managedObject.syncState = Int16(newValue.rawValue)
        }
    }
    var syncType: SyncType {
        get {
            return SyncType(rawValue: Int(managedObject.syncType)) ?? .newEntries
        }
        set {
            syncIndexToContinue = ""
            managedObject.syncType = Int16(newValue.rawValue)
        }
    }
    var syncIndexToContinue: String {
        get { return managedObject.syncIndexToContinue }
        set { managedObject.syncIndexToContinue = newValue }
    }
    var version: LibrarySyncVersion {
        get { return LibrarySyncVersion(rawValue: Int(managedObject.version)) ?? .defaultValue }
        set { managedObject.version = Int16(newValue.rawValue) }
    }
    var isInitialWave: Bool {
        return managedObject.id == 0
    }
    var isDone: Bool {
        return syncState == .Done
    }
    
    var libraryChangeDates: LibraryChangeDates {
        let temp = LibraryChangeDates()
        temp.dateOfLastUpdate = managedObject.dateOfLastUpdate ?? Date()
        temp.dateOfLastAdd = managedObject.dateOfLastAdd ?? Date()
        temp.dateOfLastClean = managedObject.dateOfLastClean ?? Date()
        return temp
    }

    func setMetaData(fromLibraryChangeDates: LibraryChangeDates) {
        managedObject.dateOfLastUpdate = fromLibraryChangeDates.dateOfLastUpdate
        managedObject.dateOfLastAdd = fromLibraryChangeDates.dateOfLastAdd
        managedObject.dateOfLastClean = fromLibraryChangeDates.dateOfLastClean
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
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SyncWave else { return false }
        return managedObject == object.managedObject
    }

}
