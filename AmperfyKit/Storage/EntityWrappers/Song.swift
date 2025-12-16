//
//  Song.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 30.12.19.
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

// MARK: - Song

public class Song: AbstractPlayable, Identifyable {
  public let managedObject: SongMO

  public init(managedObject: SongMO) {
    self.managedObject = managedObject
    super.init(managedObject: managedObject)
  }

  public var lyricsRelFilePath: URL? {
    get {
      guard let lyricsRelFilePathString = managedObject.lyricsRelFilePath else { return nil }
      return URL(string: lyricsRelFilePathString)
    }
    set {
      managedObject.lyricsRelFilePath = newValue?.path
    }
  }

  public var album: Album? {
    get {
      guard let albumMO = managedObject.album else { return nil }
      return Album(managedObject: albumMO)
    }
    set {
      if managedObject.album != newValue?
        .managedObject { managedObject.album = newValue?.managedObject }
    }
  }

  public var artist: Artist? {
    get {
      guard let artistMO = managedObject.artist else { return nil }
      return Artist(managedObject: artistMO)
    }
    set {
      if managedObject.artist != newValue?
        .managedObject { managedObject.artist = newValue?.managedObject }
    }
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

  public var addedDate: Date? {
    get {
      guard let addedDateMO = managedObject.addedDate else { return nil }
      return addedDateMO
    }
    set {
      managedObject.addedDate = newValue
    }
  }

  public var isOrphaned: Bool {
    guard let album = album else { return true }
    return album.isOrphaned
  }

  public override func deleteCache() {
    album?.isCached = false
    for playlistItemMO in managedObject.playlistItems {
      if playlistItemMO.playlist.isCached {
        playlistItemMO.playlist.isCached = false
      }
    }
    if managedObject.directory?.isCached ?? false {
      managedObject.directory?.isCached = false
    }
    if managedObject.musicFolder?.isCached ?? false {
      managedObject.musicFolder?.isCached = false
    }
  }

  override public var creatorName: String {
    artist?.name ?? "Unknown Artist"
  }

  public var detailInfo: String {
    var info = displayString
    info += " ("
    let albumName = album?.name ?? "-"
    info += "album: \(albumName),"
    let genreName = genre?.name ?? "-"
    info += " genre: \(genreName),"

    info += " id: \(id),"
    info += " track: \(track),"
    info += " year: \(year),"
    info += " remote duration: \(remoteDuration),"
    let diskInfo = disk ?? "-"
    info += " disk: \(diskInfo),"
    info += " size: \(size),"
    let contentTypeInfo = contentType ?? "-"
    info += " contentType: \(contentTypeInfo),"
    info += " bitrate: \(bitrate)"
    info += ")"
    return info
  }

  override public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if details.type == .long {
      if track > 0 {
        infoContent.append("Track \(track)")
      }
      if duration > 0 {
        infoContent.append("\(duration.asDurationString)")
      }
      if year > 0 {
        infoContent.append("Year \(year)")
      } else if let albumYear = album?.year, albumYear > 0 {
        infoContent.append("Year \(albumYear)")
      }
      if let genre = genre {
        infoContent.append("Genre: \(genre.name)")
      }
      if details.isShowDetailedInfo {
        if bitrate > 0 {
          infoContent.append("Bitrate: \(bitrate)")
        }
        if isCached {
          if let contentType = contentType, let fileContentType = fileContentType,
             contentType != fileContentType {
            infoContent.append("Transcoded MIME Type: \(fileContentType)")
            infoContent.append("Original MIME Type: \(contentType)")
          } else if let contentType = contentType {
            infoContent.append("Cache MIME Type: \(contentType)")
          } else if let fileContentType = fileContentType {
            infoContent.append("Cache MIME Type: \(fileContentType)")
          }
        }
        infoContent.append("ID: \(!id.isEmpty ? id : "-")")
      }
    }
    return infoContent
  }

  public var identifier: String {
    title
  }

  override public func isAvailableToUser() -> Bool {
    // See also SongMO.excludeServerDeleteUncachedSongsFetchPredicate()
    ((size > 0) && (album?.remoteStatus == .available)) || isCached
  }
}

extension Array where Element: Song {
  public func filterServerDeleteUncachedSongs() -> [Element] {
    filter { $0.isAvailableToUser() }
  }

  public func filterCached() -> [Element] {
    filter { $0.isCached }
  }

  public func filterCustomArt() -> [Element] {
    filter { $0.artwork != nil }
  }

  public var hasCachedSongs: Bool {
    lazy.filter { $0.isCached }.first != nil
  }

  public func sortByTrackNumber() -> [Element] {
    sorted {
      if $0.disk != $1.disk {
        return $0.disk ?? "" < $1.disk ?? ""
      } else if $0.track != $1.track {
        return $0.track < $1.track
      } else if $0.title != $1.title {
        return $0.title < $1.title
      } else {
        return $0.id < $1.id
      }
    }
  }

  public func sortByAlbum() -> [Element] {
    sorted {
      if $0.album?.year != $1.album?.year {
        return $0.album?.year ?? 0 < $1.album?.year ?? 0
      } else if $0.album?.id != $1.album?.id {
        return $0.album?.id ?? "" < $1.album?.id ?? ""
      } else if $0.disk != $1.disk {
        return $0.disk ?? "" < $1.disk ?? ""
      } else if $0.track != $1.track {
        return $0.track < $1.track
      } else if $0.title != $1.title {
        return $0.title < $1.title
      } else {
        return $0.id < $1.id
      }
    }
  }
}
