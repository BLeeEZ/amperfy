//
//  PlaylistSongsParserDelegate.swift
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
import UIKit

class PlaylistSongsParserDelegate: SongParserDelegate {
  let playlist: Playlist
  var items: [PlaylistItem]
  private var playlistChanged = false

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    playlist: Playlist,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.playlist = playlist
    self.items = playlist.items
    super.init(
      performanceMonitor: performanceMonitor,
      prefetch: prefetch,
      account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "playlisttrack":
      let index = Int(parsedCount)
      var item: PlaylistItem?

      if let song = songBuffer {
        if index < items.count {
          item = items[index]
          if item?.playable.id != song.id {
            playlistChanged = true
            item?.playable = song
          }
        } else {
          playlist.createAndAppendPlaylistItem(for: song)
          playlistChanged = true
        }
      }
    case "root":
      if items.count > parsedCount {
        for i in Array(parsedCount ... items.count - 1) {
          library.deletePlaylistItem(item: items[i])
        }
        playlistChanged = true
      }
      if playlistChanged {
        playlist.updateChangeDate()
        playlist.updateArtworkItems()
        playlist.remoteDuration = collectionDuration
      }
      playlist.isCached = isCollectionCached
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
