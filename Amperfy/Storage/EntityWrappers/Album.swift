import Foundation
import CoreData
import UIKit

public class Album: AbstractLibraryEntity, SongContainable {
    
    let managedObject: AlbumMO
    
    init(managedObject: AlbumMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    override var identifier: String {
        return name
    }
    
    var name: String {
        get { return managedObject.name ?? "Unknown Album" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    var year: Int {
        get { return Int(managedObject.year) }
        set {
            guard newValue > Int16.min, newValue < Int16.max, managedObject.year != Int16(newValue) else { return }
            managedObject.year = Int16(newValue)
        }
    }
    var artist: Artist? {
        get {
            guard let artistMO = managedObject.artist else { return nil }
            return Artist(managedObject: artistMO)
        }
        set {
            if managedObject.artist != newValue?.managedObject { managedObject.artist = newValue?.managedObject }
        }
    }
    var genre: Genre? {
        get {
            guard let genreMO = managedObject.genre else { return nil }
            return Genre(managedObject: genreMO) }
        set {
            if managedObject.genre != newValue?.managedObject { managedObject.genre = newValue?.managedObject }
        }
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }
    var songCount: Int {
        get { return Int(managedObject.songCount) }
        set {
            guard newValue > Int16.min, newValue < Int16.max, managedObject.songCount != Int16(newValue) else { return }
            managedObject.songCount = Int16(newValue)
        }
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
