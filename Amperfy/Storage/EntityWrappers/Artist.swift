import Foundation
import CoreData
import UIKit

public class Artist: AbstractLibraryEntity, SongContainable {
    
    let managedObject: ArtistMO
    
    init(managedObject: ArtistMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    override var identifier: String {
        return name
    }
    
    var songs: [Song] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
          returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs
    }
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    var name: String {
        get { return managedObject.name ?? "Unknown artist" }
        set { managedObject.name = newValue }
    }
    var albums: [Album] {
        guard let albumsSet = managedObject.albums, let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
        var returnAlbums = [Album]()
        for albumMO in albumsMO {
            returnAlbums.append(Album(managedObject: albumMO))
        }
        return returnAlbums
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set { managedObject.syncInfo = newValue?.managedObject }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Artist else { return false }
        return managedObject == object.managedObject
    }

}
