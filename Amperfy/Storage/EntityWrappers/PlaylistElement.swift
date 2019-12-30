import Foundation
import CoreData

public class PlaylistElement: NSObject {

    let managedObject: PlaylistElementMO
    private let storage: LibraryStorage
    
    init(storage: LibraryStorage, managedObject: PlaylistElementMO) {
        self.storage = storage
        self.managedObject = managedObject
    }
    
    var objectID: NSManagedObjectID {
        return managedObject.objectID
    }

    var index: Int? {
         return managedObject.index
    }
    var order: Int {
         get { return Int(managedObject.order) }
         set { managedObject.order = Int32(newValue) }
     }
    var song: Song? {
        get {
            guard let songMO = managedObject.song else { return nil }
            return Song(managedObject: songMO) }
        set { managedObject.song = newValue?.managedObject }
    }
    var playlist: Playlist? {
        get {
            guard let playlistMO = managedObject.playlist else {
                return nil
            }
            return Playlist(storage: storage, managedObject: playlistMO)
        }
        set {
            guard let newPlaylist = newValue else {
                managedObject.playlist = nil
                return
            }
            managedObject.playlist = newPlaylist.managedObject
        }
    }
    
}
