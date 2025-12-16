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

import CoreData
import Foundation
import UIKit

// MARK: - Artist

public class Artist: AbstractLibraryEntity {
  public let managedObject: ArtistMO

  public init(managedObject: ArtistMO) {
    self.managedObject = managedObject
    super.init(managedObject: managedObject)
  }

  public var identifier: String {
    name
  }

  public var songCount: Int {
    Int(managedObject.songCount)
  }

  public var songs: [AbstractPlayable] {
    guard let songsSet = managedObject.songs,
          let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
    var returnSongs = [Song]()
    for songMO in songsMO {
      returnSongs.append(Song(managedObject: songMO))
    }
    return returnSongs.sortByAlbum()
  }

  public var playables: [AbstractPlayable] { songs }

  public var name: String {
    get { managedObject.name ?? "Unknown Artist" }
    set {
      if managedObject.name != newValue {
        managedObject.name = newValue
        updateAlphabeticSectionInitial(section: newValue)
      }
    }
  }

  public var duration: Int { Int(managedObject.duration) }

  public var remoteDuration: Int {
    get { Int(managedObject.remoteDuration) }
    set {
      if managedObject.remoteDuration != Int64(newValue) {
        managedObject.remoteDuration = Int64(newValue)
      }
      if managedObject.duration != Int64(newValue) {
        managedObject.duration = Int64(newValue)
      }
    }
  }

  public var remoteAlbumCount: Int {
    get {
      Int(managedObject.remoteAlbumCount)
    }
    set {
      guard Int16.isValid(value: newValue),
            managedObject.remoteAlbumCount != Int16(newValue) else { return }
      managedObject.remoteAlbumCount = Int16(newValue)
    }
  }

  public var albumCount: Int { Int(managedObject.albumCount) }

  public var albums: [Album] {
    guard let albumsSet = managedObject.albums,
          let albumsMO = albumsSet.array as? [AlbumMO] else { return [Album]() }
    var returnAlbums = [Album]()
    for albumMO in albumsMO {
      returnAlbums.append(Album(managedObject: albumMO))
    }
    return returnAlbums
  }

  public var genre: Genre? {
    get {
      guard let genreMO = managedObject.genre else { return nil }
      return Genre(managedObject: genreMO)
    }
    set {
      if managedObject.genre != newValue?
        .managedObject { managedObject.genre = newValue?.managedObject }
    }
  }

  override public func getDefaultArtworkType() -> ArtworkType {
    .artist
  }
}

// MARK: PlayableContainable

extension Artist: PlayableContainable {
  public var subtitle: String? { nil }
  public var subsubtitle: String? { nil }
  public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if let managedObjectContext = managedObject.managedObjectContext, let account {
      let library = LibraryStorage(context: managedObjectContext)
      let relatedAlbumCount = library.getAlbums(for: account, whichContainsSongsWithArtist: self)
        .count
      if relatedAlbumCount == 1 {
        infoContent.append("1 Album")
      } else if relatedAlbumCount > 1 {
        infoContent.append("\(relatedAlbumCount) Albums")
      }
    } else if albumCount == 1 {
      infoContent.append("1 Album")
    } else if albumCount > 1 {
      infoContent.append("\(albumCount) Albums")
    }

    if details.artistFilterSetting == .albumArtists,
       let managedObjectContext = managedObject.managedObjectContext, let account {
      let library = LibraryStorage(context: managedObjectContext)
      let relatedSongsCount = library.getSongs(for: account, whichContainsSongsWithArtist: self)
        .count
      if relatedSongsCount == 1 {
        infoContent.append("1 Song")
      } else if relatedSongsCount > 1 {
        infoContent.append("\(relatedSongsCount) Songs")
      }
    } else if songCount == 1 {
      infoContent.append("1 Song")
    } else if songCount > 1 {
      infoContent.append("\(songCount) Songs")
    }
    if details.type == .short, details.isShowArtistDuration, duration > 0 {
      infoContent.append("\(duration.asDurationShortString)")
    }
    if details.type == .long {
      if let genre = genre {
        infoContent.append("Genre: \(genre.name)")
      }
      if duration > 0 {
        infoContent.append("\(duration.asDurationShortString)")
      }
      if details.isShowDetailedInfo {
        infoContent.append("ID: \(!id.isEmpty ? id : "-")")
      }
    }
    return infoContent
  }

  public var playContextType: PlayerMode { .music }
  public var isRateable: Bool { true }
  public var isFavoritable: Bool { true }
  @MainActor
  public func remoteToggleFavorite(syncer: LibrarySyncer) async throws {
    guard let context = managedObject.managedObjectContext else {
      throw BackendError.persistentSaveFailed
    }
    isFavorite.toggle()
    let library = LibraryStorage(context: context)
    library.saveContext()
    try await syncer.setFavorite(artist: self, isFavorite: isFavorite)
  }

  @MainActor
  public func fetchFromServer(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws {
    try await librarySyncer.sync(artist: self)
  }

  public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
    ArtworkCollection(defaultArtworkType: .artist, singleImageEntity: self)
  }

  public var containerIdentifier: PlayableContainerIdentifier { PlayableContainerIdentifier(
    type: .artist,
    objectID: managedObject.objectID.uriRepresentation().absoluteString
  ) }
}
