import Foundation
import CoreData
import UIKit

public class Album: AbstractLibraryEntity {
    
    let managedObject: AlbumMO
    
    init(managedObject: AlbumMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    override var identifier: String {
        return name
    }
    
    var name: String {
        get { return managedObject.name ?? "Unknown artist" }
        set { managedObject.name = newValue }
    }
    var year: Int {
        get { return Int(managedObject.year) }
        set { managedObject.year = Int16(newValue) }
    }
    var artist: Artist? {
        get {
            guard let artistMO = managedObject.artist else { return nil }
            return Artist(managedObject: artistMO)
        }
        set { managedObject.artist = newValue?.managedObject }
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set { managedObject.syncInfo = newValue?.managedObject }
    }
    var songs: [Song] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
            returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs.sortByTrackNumber()
    }
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    var isOrphaned: Bool {
        return identifier == "Unknown (Orphaned)"
    }
    
    override var image: UIImage {
        if super.image != Artwork.defaultImage {
            return super.image
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Album else { return false }
        return managedObject == object.managedObject
    }

}
