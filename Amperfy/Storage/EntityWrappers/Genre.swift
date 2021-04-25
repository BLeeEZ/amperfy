import Foundation
import CoreData
import UIKit

public class Genre: AbstractLibraryEntity, SongContainable {
    
    let managedObject: GenreMO
    
    init(managedObject: GenreMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    var name: String {
        get { return managedObject.name ?? "Unknown Genre" }
        set { managedObject.name = newValue }
    }
    override var identifier: String {
        return name
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
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set { managedObject.syncInfo = newValue?.managedObject }
    }

}
