//
//  PlaylistParserDelegate.swift
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

class PlaylistParserDelegate: AmpacheNotifiableXmlParser {
  private var playlist: Playlist?
  private var playlistToValidate: Playlist?
  private var playlistsDict: [String: Playlist]
  private let allOldPlaylists: Set<Playlist>
  private var parsedPlaylists: Set<Playlist>
  private var account: Account
  private var library: LibraryStorage

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    account: Account,
    library: LibraryStorage,
    parseNotifier: ParsedObjectNotifiable?,
    playlistToValidate: Playlist? = nil
  ) {
    self.account = account
    self.library = library
    self.playlist = playlistToValidate
    self.playlistToValidate = playlistToValidate
    self.allOldPlaylists = Set(library.getPlaylists(for: account))
    self.playlistsDict = [String: Playlist]()
    for pl in allOldPlaylists {
      playlistsDict[pl.id] = pl
    }
    self.parsedPlaylists = Set<Playlist>()
    super.init(performanceMonitor: performanceMonitor, parseNotifier: parseNotifier)
  }

  private func resetPlaylistInCaseOfError() {
    if playlist != nil {
      os_log("Error: Playlist has been removed on server -> local id reset", log: log, type: .error)
      playlist?.id = ""
      playlist = nil
    }
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

    switch elementName {
    case "playlist":
      guard let playlistId = attributeDict["id"] else {
        os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
        resetPlaylistInCaseOfError()
        return
      }

      if playlist != nil {
        playlist?.id = playlistId
      } else if playlistId != "" {
        if let fetchedPlaylist = playlistsDict[playlistId] {
          playlist = fetchedPlaylist
        } else {
          playlist = library.createPlaylist(account: account)
          playlist?.id = playlistId
          playlistsDict[playlistId] = playlist
        }
      } else {
        os_log("Error: Playlist could not be parsed -> id is not given", log: log, type: .error)
      }
    default:
      break
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "name":
      playlist?.name = buffer
    case "items":
      playlist?.remoteSongCount = Int(buffer) ?? 0
    case "playlist":
      if let parsedPlaylist = playlist {
        parsedPlaylists.insert(parsedPlaylist)
      }
      playlist = nil
      parseNotifier?.notifyParsedObject(ofType: .playlist)
    case "root":
      if playlistToValidate == nil {
        let outdatedPlaylists = allOldPlaylists.subtracting(parsedPlaylists)
        outdatedPlaylists.forEach {
          if $0.id != "" {
            library.deletePlaylist($0)
          }
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
