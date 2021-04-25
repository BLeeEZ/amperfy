import Foundation
import CoreData
import UIKit

public class Song: AbstractLibraryEntity {
     /*
     Avoid direct access to the SongFile.
     Direct access will result in loading the file into memory and
     it sticks there till the song is removed from memory.
     This will result in memory overflow for an array of songs.
     */
     let managedObject: SongMO

     init(managedObject: SongMO) {
         self.managedObject = managedObject
         super.init(managedObject: managedObject)
     }

     var objectID: NSManagedObjectID {
         return managedObject.objectID
     }
     var title: String {
         get { return managedObject.title ?? "Unknown Title" }
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
     var duration: Int {
        get { return Int(managedObject.duration) }
        set { managedObject.duration = Int16(newValue) }
     }
     var size: Int {
        get { return Int(managedObject.size) }
        set { managedObject.size = Int32(newValue) }
     }
     var bitrate: Int { // byte per second
        get { return Int(managedObject.bitrate) }
        set { managedObject.bitrate = Int32(newValue) }
     }
     var contentType: String? {
        get { return managedObject.contentType }
        set { managedObject.contentType = newValue }
     }
     var disk: String? {
        get { return managedObject.disk }
        set { managedObject.disk = newValue }
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
     var genre: Genre? {
         get {
             guard let genreMO = managedObject.genre else { return nil }
             return Genre(managedObject: genreMO) }
         set { managedObject.genre = newValue?.managedObject }
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
    
    var detailInfo: String {
        var info = displayString
        info += " ("
        let albumName = album?.name ?? "-"
        info += "album: \(albumName),"
        let genreName = genre?.name ?? "-"
        info += " genre: \(genreName),"
        
        info += " id: \(id),"
        info += " track: \(track),"
        info += " year: \(year),"
        info += " duration: \(duration),"
        let diskInfo =  disk ?? "-"
        info += " disk: \(diskInfo),"
        info += " size: \(size),"
        let contentTypeInfo = contentType ?? "-"
        info += " contentType: \(contentTypeInfo),"
        info += " bitrate: \(bitrate)"

        
        info += ")"
        return info
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
        if managedObject.file != nil {
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
        return self.filter{ $0.isCached }
    }
    
    func filterCustomArt() -> [Element] {
        return self.filter{ $0.image != Artwork.defaultImage }
    }
    
    var hasCachedSongs: Bool {
        return self.lazy.filter{ $0.isCached }.first != nil
    }
    
    func sortByTrackNumber() -> [Element] {
        return self.sorted{ $0.track < $1.track }
    }
    
}
