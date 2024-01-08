//
//  Genre.swift
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
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var duration: Int {
        return playables.reduce(0){ $0 + $1.duration }
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
    override public var defaultImage: UIImage {
        return UIImage.genreArtwork
    }

}

extension Genre: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
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
        if details.type == .long {
            if isCompletelyCached {
                infoContent.append("Cached")
            }
            let completeDuration = songs.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playables: [AbstractPlayable] {
        return songs
    }
    public var playContextType: PlayerMode { return .music }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        return librarySyncer.sync(genre: self)
    }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        return Promise<Void>(error: BackendError.notSupported)
    }
    public var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
    }
}
