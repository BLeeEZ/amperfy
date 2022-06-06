import Foundation
import CoreData
import UIKit

public class Genre: AbstractLibraryEntity {
    
    public let managedObject: GenreMO
    
    public init(managedObject: GenreMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var identifier: String {
        return name
    }
    public var name: String {
        get { return managedObject.name ?? "Unknown Genre" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    public var artists: [Artist] {
        guard let artistsSet = managedObject.artists, let artistsMO = artistsSet.array as? [ArtistMO] else { return [Artist]() }
        return artistsMO.compactMap {
            Artist(managedObject: $0)
        }
    }
    public var albums: [Album] {
        guard let albumsSet = managedObject.albums, let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
        return albumsMO.compactMap {
            Album(managedObject: $0)
        }
    }
    public var songs: [Song] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        return songsMO.compactMap {
            Song(managedObject: $0)
        }
    }
    public var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }
    override public var defaultImage: UIImage {
        return UIImage.genreArtwork
    }

}

extension Genre: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if api == .ampache {
            if artists.count == 1 {
                infoContent.append("1 Artist")
            } else if artists.count > 1 {
                infoContent.append("\(artists.count) Artists")
            }
        }
        if albums.count == 1 {
            infoContent.append("1 Album")
        } else if albums.count > 1 {
            infoContent.append("\(albums.count) Albums")
        }
        if songs.count == 1 {
            infoContent.append("1 Song")
        } else if songs.count > 1 {
            infoContent.append("\(songs.count) Songs")
        }
        if type == .long {
            let completeDuration = songs.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationString)")
            }
        }
        return infoContent
    }
    public var playables: [AbstractPlayable] {
        return songs
    }
    public var playContextType: PlayerMode { return .music }
    public func fetchFromServer(inContext context: NSManagedObjectContext, backendApi: BackendApi, settings: PersistentStorage.Settings, playableDownloadManager: DownloadManageable) {
        let syncer = backendApi.createLibrarySyncer()
        let library = LibraryStorage(context: context)
        let genreAsync = Genre(managedObject: context.object(with: managedObject.objectID) as! GenreMO)
        syncer.sync(genre: genreAsync, library: library)
    }
    public var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
    }
}
