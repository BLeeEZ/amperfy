import Foundation
import CoreData
import UIKit

public class Album: AbstractLibraryEntity {
    
    let managedObject: AlbumMO
    
    init(managedObject: AlbumMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    override func image(setting: ArtworkDisplayPreference) -> UIImage {
        switch setting {
        case .id3TagOnly:
            return embeddedArtworkImage ?? defaultImage
        case .serverArtworkOnly:
            return super.image(setting: setting)
        case .preferServerArtwork:
            return artwork?.image ?? embeddedArtworkImage ?? defaultImage
        case .preferId3Tag:
            return embeddedArtworkImage ?? artwork?.image ?? defaultImage
        }
    }
    private var embeddedArtworkImage: UIImage? {
        return songs.lazy.compactMap{ $0.embeddedArtwork }.first?.image
    }
    var identifier: String {
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
            guard Int16.isValid(value: newValue), managedObject.year != Int16(newValue) else { return }
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
        get {
            let moSongCount = Int(managedObject.songCount)
            return moSongCount != 0 ? moSongCount : (managedObject.songs?.count ?? 0)
        }
        set {
            guard Int16.isValid(value: newValue), managedObject.songCount != Int16(newValue) else { return }
            managedObject.songCount = Int16(newValue)
        }
    }
    var songs: [AbstractPlayable] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
            returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs.sortByTrackNumber()
    }
    var playables: [AbstractPlayable] { return songs }
    
    var isOrphaned: Bool {
        return identifier == "Unknown (Orphaned)"
    }
    override var defaultImage: UIImage {
        return UIImage.albumArtwork
    }

}

extension Album: PlayableContainable  {
    var subtitle: String? { return artist?.name }
    var subsubtitle: String? { return nil }
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if songs.count == 1 {
            infoContent.append("1 Song")
        } else if songs.count > 1 {
            infoContent.append("\(songs.count) Songs")
        } else if songCount == 1 {
            infoContent.append("1 Song")
        } else if songCount > 1 {
            infoContent.append("\(songCount) Songs")
        }
        if type == .long {
            if year > 0 {
                infoContent.append("Year \(year)")
            }
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationString)")
            }
        }
        return infoContent
    }
    var playContextType: PlayerMode { return .music }
    var isRateable: Bool { return true }
    var isFavoritable: Bool { return true }
    func remoteToggleFavorite(inContext context: NSManagedObjectContext, syncer: LibrarySyncer) {
        let library = LibraryStorage(context: context)
        let albumAsync = Album(managedObject: context.object(with: managedObject.objectID) as! AlbumMO)
        albumAsync.isFavorite.toggle()
        library.saveContext()
        syncer.setFavorite(album: albumAsync, isFavorite: albumAsync.isFavorite)
    }
    func fetchFromServer(inContext context: NSManagedObjectContext, syncer: LibrarySyncer) {
        let library = LibraryStorage(context: context)
        let albumAsync = Album(managedObject: context.object(with: managedObject.objectID) as! AlbumMO)
        syncer.sync(album: albumAsync, library: library)
    }
    var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
    }
}

extension Album: Hashable, Equatable {
    public static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
