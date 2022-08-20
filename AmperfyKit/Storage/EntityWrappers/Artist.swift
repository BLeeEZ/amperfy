//
//  Artist.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 31.12.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import UIKit

public class Artist: AbstractLibraryEntity {
    
    public let managedObject: ArtistMO
    
    public init(managedObject: ArtistMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var identifier: String {
        return name
    }
    
    public var songCount: Int {
        return managedObject.songs?.count ?? 0
    }
    public var songs: [AbstractPlayable] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
          returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs.sortByAlbum()
    }
    public var playables: [AbstractPlayable] { return songs }
    
    public var name: String {
        get { return managedObject.name ?? "Unknown Artist" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    public var albumCount: Int {
        get {
            let moAlbumCount = Int(managedObject.albumCount)
            return moAlbumCount != 0 ? moAlbumCount : (managedObject.albums?.count ?? 0)
        }
        set {
            guard Int16.isValid(value: newValue), managedObject.albumCount != Int16(newValue) else { return }
            managedObject.albumCount = Int16(newValue)
        }
    }
    public var albums: [Album] {
        guard let albumsSet = managedObject.albums, let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
        var returnAlbums = [Album]()
        for albumMO in albumsMO {
            returnAlbums.append(Album(managedObject: albumMO))
        }
        return returnAlbums
    }
    public var genre: Genre? {
        get {
            guard let genreMO = managedObject.genre else { return nil }
            return Genre(managedObject: genreMO) }
        set {
            if managedObject.genre != newValue?.managedObject { managedObject.genre = newValue?.managedObject }
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
        return UIImage.artistArtwork
    }

}

extension Artist: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
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
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationString)")
            }
        }
        return infoContent
    }
    public var playContextType: PlayerMode { return .music }
    public var isRateable: Bool { return true }
    public var isFavoritable: Bool { return true }
    public func remoteToggleFavorite(inContext context: NSManagedObjectContext, syncer: LibrarySyncer) {
        let library = LibraryStorage(context: context)
        let artistAsync = Artist(managedObject: context.object(with: managedObject.objectID) as! ArtistMO)
        artistAsync.isFavorite.toggle()
        library.saveContext()
        syncer.setFavorite(artist: artistAsync, isFavorite: artistAsync.isFavorite)
    }
    public func fetchFromServer(inContext context: NSManagedObjectContext, backendApi: BackendApi, settings: PersistentStorage.Settings, playableDownloadManager: DownloadManageable) {
        let syncer = backendApi.createLibrarySyncer()
        let library = LibraryStorage(context: context)
        let artistAsync = Artist(managedObject: context.object(with: managedObject.objectID) as! ArtistMO)
        syncer.sync(artist: artistAsync, library: library)
    }
    public var artworkCollection: ArtworkCollection {
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
