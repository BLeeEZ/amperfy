//
//  SsPlaylistParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
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
import os.log
import UIKit

class SsPlaylistParserDelegate: SsXmlParser {
  private var playlist: Playlist?
  private let oldPlaylists: Set<Playlist>
  private var parsedPlaylists: Set<Playlist>
  private let library: LibraryStorage

  init(performanceMonitor: ThreadPerformanceMonitor, library: LibraryStorage) {
    self.library = library
    self.oldPlaylists = Set(library.getPlaylists())
    self.parsedPlaylists = Set<Playlist>()
    super.init(performanceMonitor: performanceMonitor)
  }

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )

    if elementName == "playlist" {
      guard let playlistId = attributeDict["id"],
            let attributePlaylistName = attributeDict["name"] else {
        return
      }

      if playlist != nil {
        playlist?.id = playlistId
      } else if playlistId != "" {
        if let fetchedPlaylist = library.getPlaylist(id: playlistId) {
          playlist = fetchedPlaylist
        } else {
          playlist = library.createPlaylist()
          playlist?.id = playlistId
        }
      } else {
        os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
        return
      }

      playlist?.name = attributePlaylistName

      if let attributeDuration = attributeDict["duration"], let duration = Int(attributeDuration) {
        playlist?.remoteDuration = duration
      }
      if let attributeSongCount = attributeDict["songCount"],
         let songCount = Int(attributeSongCount) {
        playlist?.remoteSongCount = songCount
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "playlist":
      parsedCount += 1
      if let parsedPlaylist = playlist {
        parsedPlaylists.insert(parsedPlaylist)
      }
      playlist = nil
    case "playlists":
      let outdatedPlaylists = oldPlaylists.subtracting(parsedPlaylists)
      outdatedPlaylists.forEach {
        if $0.id != "" {
          library.deletePlaylist($0)
        }
      }
    default:
      break
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
