import Foundation
import CoreData
import UIKit

public class Artist: AbstractLibraryEntity {
    
    let managedObject: ArtistMO
    
    init(managedObject: ArtistMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    var identifier: String {
        return name
    }
    
    var songCount: Int {
        return managedObject.songs?.count ?? 0
    }
    var songs: [AbstractPlayable] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
          returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs
    }
    var playables: [AbstractPlayable] { return songs }
    
    var name: String {
        get { return managedObject.name ?? "Unknown Artist" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    var albumCount: Int {
        get {
            let moAlbumCount = Int(managedObject.albumCount)
            return moAlbumCount != 0 ? moAlbumCount : (managedObject.albums?.count ?? 0)
        }
        set {
            guard Int16.isValid(value: newValue), managedObject.albumCount != Int16(newValue) else { return }
            managedObject.albumCount = Int16(newValue)
        }
    }
    var albums: [Album] {
        guard let albumsSet = managedObject.albums, let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
        var returnAlbums = [Album]()
        for albumMO in albumsMO {
            returnAlbums.append(Album(managedObject: albumMO))
        }
        return returnAlbums
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
    override var defaultImage: UIImage {
        return UIImage.artistArtwork
    }

}

extension Artist: PlayableContainable  {
    var subtitle: String? { return nil }
    var subsubtitle: String? { return nil }
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if let managedObjectContext = managedObject.managedObjectContext {
            let library = LibraryStorage(context: managedObjectContext)
            let relatedAlbumCount = library.getAlbums(whichContainsSongsWithArtist: self).count
            if relatedAlbumCount == 1 {
                infoContent.append("1 Album")
            } else if relatedAlbumCount > 1 {
                infoContent.append("\(relatedAlbumCount) Albums")
            }
        } else if albums.count == 1 {
            infoContent.append("1 Album")
        } else if albums.count > 1 {
            infoContent.append("\(albums.count) Albums")
        } else if albumCount == 1 {
            infoContent.append("1 Album")
        } else if albumCount > 1 {
            infoContent.append("\(albumCount) Albums")
        }
        
        if songs.count == 1 {
            infoContent.append("1 Song")
        } else if songs.count > 1 {
            infoContent.append("\(songCount) Songs")
        }
        if type == .long {
            infoContent.append("\(duration.asDurationString)")
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
        }
        return infoContent
    }
    var isRateable: Bool { return true }
    func fetchFromServer(inContext context: NSManagedObjectContext, syncer: LibrarySyncer) {
        let library = LibraryStorage(context: context)
        let artistAsync = Artist(managedObject: context.object(with: managedObject.objectID) as! ArtistMO)
        syncer.sync(artist: artistAsync, library: library)
    }
    var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
    }
}

extension Artist: Hashable, Equatable {
    public static func == (lhs: Artist, rhs: Artist) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
