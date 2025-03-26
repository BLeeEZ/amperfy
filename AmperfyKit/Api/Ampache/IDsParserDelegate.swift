//
//  IDsParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 22.03.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

class IDsParserDelegate: AmpacheNotifiableXmlParser {
  public private(set) var prefetchIDs = LibraryStorage.PrefetchIdContainer()

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
    case "genre":
      if let id = attributeDict["id"] {
        prefetchIDs.genreIDs.insert(id)
      }
    case "catalog":
      if let id = attributeDict["id"] {
        prefetchIDs.musicFolderIDs.insert(id)
      }
    case "artist":
      if let id = attributeDict["id"] {
        prefetchIDs.artistIDs.insert(id)
      }
    case "album":
      if let id = attributeDict["id"] {
        prefetchIDs.albumIDs.insert(id)
      }
    case "song":
      if let id = attributeDict["id"] {
        prefetchIDs.songIDs.insert(id)
      }
    case "podcast_episode":
      if let id = attributeDict["id"] {
        prefetchIDs.podcastEpisodeIDs.insert(id)
      }
    case "live_stream":
      if let id = attributeDict["id"] {
        prefetchIDs.radioIDs.insert(id)
      }
    case "podcast":
      if let id = attributeDict["id"] {
        prefetchIDs.podcastIDs.insert(id)
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
    if elementName == "art", let artworkRemoteInfo = AmpacheXmlServerApi
      .extractArtworkInfoFromURL(urlString: buffer) {
      prefetchIDs.artworkIDs.insert(artworkRemoteInfo)
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
