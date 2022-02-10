import Foundation
import CoreData
import UIKit

public class Genre: AbstractLibraryEntity {
    
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
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }

}

extension Genre: PlayableContainable  {
    var subtitle: String? { return nil }
    var subsubtitle: String? { return nil }
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if api == .ampache {
            if artists.count == 1 {
                infoContent.append("1 Artist")
            } else {
                infoContent.append("\(artists.count) Artists")
            }
        }
        if albums.count == 1 {
            infoContent.append("1 Album")
        } else {
            infoContent.append("\(albums.count) Albums")
        }
        if songs.count == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(songs.count) Songs")
        }
        if type == .long {
            infoContent.append("\(songs.reduce(0, {$0 + $1.duration}).asDurationString)")
        }
        return infoContent
    }
    var playables: [AbstractPlayable] {
        return songs
    }
}
