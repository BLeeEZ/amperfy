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

import Foundation
import UIKit
import CoreData

class PlaylistSongsParserDelegate: SongParserDelegate {

    let playlist: Playlist
    var items: [PlaylistItem]

    init(playlist: Playlist, library: LibraryStorage) {
        self.playlist = playlist
        self.items = playlist.items
        super.init(library: library, parseNotifier: nil)
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlisttrack":
            var order = 0
            if let playlistItemOrder = Int(buffer), playlistItemOrder > 0 {
                // Ampache playlist order is one-based -> Amperfy playlist order is zero-based
                order = playlistItemOrder - 1
            }
            var item: PlaylistItem?
            if order < items.count {
                item = items[order]
            } else {
                item = library.createPlaylistItem()
                item?.order = order
                playlist.add(item: item!)
            }
            if item?.playable?.id != songBuffer?.id {
                playlist.updateChangeDate()
            }
            item?.playable = songBuffer
        case "root":
            if items.count > parsedCount {
                for i in Array(parsedCount...items.count-1) {
                    library.deletePlaylistItem(item: items[i])
                }
            }
            playlist.updateDuration()
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }
    
}
