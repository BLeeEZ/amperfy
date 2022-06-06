import Foundation
import CoreData

public class PlaylistItem: NSObject {

    public let managedObject: PlaylistItemMO
    private let library: LibraryStorage
    
    public init(library: LibraryStorage, managedObject: PlaylistItemMO) {
        self.library = library
        self.managedObject = managedObject
    }
    
    public var objectID: NSManagedObjectID {
        return managedObject.objectID
    }

    public var index: Int? {
        // Check if object has been deleted
        guard (managedObject.managedObjectContext != nil) else {
            return nil
        }
        return order
    }
    public var order: Int {
        get { return Int(managedObject.order) }
        set {
            guard Int32.isValid(value: newValue), managedObject.order != Int32(newValue) else { return }
            managedObject.order = Int32(newValue)
        }
     }
    public var playable: AbstractPlayable? {
        get {
            guard let playableMO = managedObject.playable else { return nil }
            return AbstractPlayable(managedObject: playableMO) }
        set { managedObject.playable = newValue?.playableManagedObject }
    }
    public var playlist: Playlist? {
        get {
            guard let playlistMO = managedObject.playlist else {
                return nil
            }
            return Playlist(library: library, managedObject: playlistMO)
        }
        set {
            guard let newPlaylist = newValue else {
                managedObject.playlist = nil
                return
            }
            managedObject.playlist = newPlaylist.managedObject
        }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlaylistItem else { return false }
        return managedObject == object.managedObject
    }

}
