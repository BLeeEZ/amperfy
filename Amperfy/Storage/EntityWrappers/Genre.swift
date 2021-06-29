import Foundation
import CoreData
import UIKit

public class Genre: AbstractLibraryEntity, PlayableContainable {
    
    let managedObject: GenreMO
    
    init(managedObject: GenreMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    var identifier: String {
        return name
    }
    var name: String {
        get { return managedObject.name ?? "Unknown Genre" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    var artists: [Artist] {
        guard let artistsSet = managedObject.artists, let artistsMO = artistsSet.array as? [ArtistMO] else { return [Artist]() }
        return artistsMO.compactMap {
            Artist(managedObject: $0)
        }
    }
    var albums: [Album] {
        guard let albumsSet = managedObject.albums, let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
        return albumsMO.compactMap {
            Album(managedObject: $0)
        }
    }
    var songs: [Song] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        return songsMO.compactMap {
            Song(managedObject: $0)
        }
    }
    var playables: [AbstractPlayable] { return songs }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }

}
