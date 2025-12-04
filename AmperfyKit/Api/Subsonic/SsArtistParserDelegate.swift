//
//  SsArtistParserDelegate.swift
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

class SsArtistParserDelegate: SsXmlLibWithArtworkParser {
  private var artistBuffer: Artist?
  var parsedArtists = [Artist]()

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

    if elementName == "artist" {
      guard let artistId = attributeDict["id"] else { return }

      if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
        artistBuffer = prefetchedArtist
      } else {
        artistBuffer = library.createArtist(account: account)
        prefetch.prefetchedArtistDict[artistId] = artistBuffer
        artistBuffer?.id = artistId
      }
      artistBuffer?.remoteStatus = .available
      if let attributeAlbumCount = attributeDict["albumCount"],
         let albumCount = Int(attributeAlbumCount) {
        artistBuffer?.remoteAlbumCount = albumCount
      }

      if let attributeArtistName = attributeDict["name"] {
        artistBuffer?.name = attributeArtistName
      }
      if let attributeCoverArtId = attributeDict["coverArt"] {
        artistBuffer?.artwork = parseArtwork(id: attributeCoverArtId)
      }
      artistBuffer?.rating = Int(attributeDict["userRating"] ?? "0") ?? 0
      artistBuffer?.isFavorite = attributeDict["starred"] != nil
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "artist":
      parsedCount += 1
      if let artist = artistBuffer {
        parsedArtists.append(artist)
      }
      artistBuffer = nil
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
