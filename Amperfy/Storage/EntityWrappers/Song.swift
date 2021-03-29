import Foundation
import CoreData
import UIKit

public class Song: AbstractLibraryEntity {
    
     let managedObject: SongMO

     init(managedObject: SongMO) {
         self.managedObject = managedObject
         super.init(managedObject: managedObject)
     }

     var objectID: NSManagedObjectID {
         return managedObject.objectID
     }
     var title: String {
         get { return managedObject.title ?? "Unknown title" }
         set { managedObject.title = newValue }
     }
     var track: Int {
         get { return Int(managedObject.track) }
         set { managedObject.track = Int16(newValue) }
     }
     var year: Int {
        get { return Int(managedObject.year) }
        set { managedObject.year = Int16(newValue) }
     }
     var duration: Int? {
        get { return managedObject.duration?.intValue }
        set {
            if let newValue = newValue {
                managedObject.duration = NSNumber(integerLiteral: newValue)
            } else {
                managedObject.duration = nil
            }
        }
     }
     var url: String? {
         get { return managedObject.url }
         set { managedObject.url = newValue }
     }
     var album: Album? {
         get {
             guard let albumMO = managedObject.album else { return nil }
             return Album(managedObject: albumMO)
         }
         set { managedObject.album = newValue?.managedObject }
     }
     var artist: Artist? {
         get {
             guard let artistMO = managedObject.artist else { return nil }
             return Artist(managedObject: artistMO)
         }
         set { managedObject.artist = newValue?.managedObject }
     }
     var file: SongFile? {
         get {
            guard let songFileMO = managedObject.file else { return nil }
            return SongFile(managedObject: songFileMO)
        }
        set { managedObject.file = newValue?.managedObject }
     }
     var fileData: Data? {
         return managedObject.file?.data
     }
     var syncInfo: SyncWave? {
         get {
             guard let syncInfoMO = managedObject.syncInfo else { return nil }
             return SyncWave(managedObject: syncInfoMO) }
         set { managedObject.syncInfo = newValue?.managedObject }
     }
    
    var displayString: String {
        return "\(managedObject.artist?.name ?? "Unknown artist") - \(title)"
    }
    
    override var identifier: String {
        return title
    }

    override var image: UIImage {
        if let curAlbum = album, !curAlbum.isOrphaned {
            if super.image != Artwork.defaultImage {
                return super.image
            }
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }

    var isCached: Bool {
        if let _ = managedObject.file?.data {
            return true
        }
        return false
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Song else { return false }
        return managedObject == object.managedObject
    }

}

extension Array where Element: Song {
    
    func filterCached() -> [Element] {
        let filteredArray = self.filter { element in
            return element.isCached
        }
        return filteredArray
    }
    
    func filterCustomArt() -> [Element] {
        let filteredArray = self.filter { element in
            return element.image != Artwork.defaultImage
        }
        return filteredArray
    }
    
    var hasCachedSongs: Bool {
        for song in self {
            if song.isCached {
                return true
            }
        }
        return false
    }
    
    func sortByTrackNumber() -> [Element] {
        return self.sorted {
            return $0.track < $1.track
        }
    }
    
}
