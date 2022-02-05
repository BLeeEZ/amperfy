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

}

extension Artist: PlayableContainable  {
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if albumCount == 1 {
            infoContent.append("1 Album")
        } else {
            infoContent.append("\(albumCount) Albums")
        }
        if songs.count == 1 {
            infoContent.append("1 Song")
        } else {
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
}

extension Artist: Hashable, Equatable {
    public static func == (lhs: Artist, rhs: Artist) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
