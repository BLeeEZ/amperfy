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
import PromiseKit

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
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var duration: Int {
        get { return Int(managedObject.duration) }
    }
    public var remoteDuration: Int {
        get { return Int(managedObject.remoteDuration) }
        set {
            if Int16.isValid(value: newValue), managedObject.remoteDuration != Int16(newValue) {
                managedObject.remoteDuration = Int16(newValue)
            }
        }
    }
    public func updateDuration() {
        let playablesDuration = playables.reduce(0){ $0 + $1.duration }
        guard Int16.isValid(value: playablesDuration), managedObject.duration != Int16(playablesDuration) else { return }
        managedObject.duration = Int16(playablesDuration)
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
    override public var defaultImage: UIImage {
        return UIImage.artistArtwork
    }

}

extension Artist: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
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
        if details.type == .short, details.isShowArtistDuration, duration > 0 {
            infoContent.append("\(duration.asDurationString)")
        }
        if details.type == .long {
            if isCompletelyCached {
                infoContent.append("Cached")
            }
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playContextType: PlayerMode { return .music }
    public var isRateable: Bool { return true }
    public var isFavoritable: Bool { return true }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        guard let context = managedObject.managedObjectContext else { return Promise<Void>(error: BackendError.persistentSaveFailed) }
        isFavorite.toggle()
        let library = LibraryStorage(context: context)
        library.saveContext()
        return syncer.setFavorite(artist: self, isFavorite: isFavorite)
    }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        librarySyncer.sync(artist: self)
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
