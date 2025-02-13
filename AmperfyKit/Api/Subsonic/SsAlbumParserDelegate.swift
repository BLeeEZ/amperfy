//
//  SsAlbumParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.04.19.
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

class SsAlbumParserDelegate: SsXmlLibWithArtworkParser {
  var guessedArtist: Artist?
  var parsedAlbums = [Album]()
  private var albumBuffer: Album?

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

    if elementName == "album" {
      guard let albumId = attributeDict["id"] else { return }

      if let fetchedAlbum = library.getAlbum(id: albumId, isDetailFaultResolution: true) {
        albumBuffer = fetchedAlbum
      } else {
        albumBuffer = library.createAlbum()
        albumBuffer?.id = albumId
      }
      albumBuffer?.remoteStatus = .available

      if let attributeAlbumtName = attributeDict["name"] {
        albumBuffer?.name = attributeAlbumtName
      }
      if let attributeCoverArt = attributeDict["coverArt"] {
        albumBuffer?.artwork = parseArtwork(id: attributeCoverArt)
      }
      albumBuffer?.rating = Int(attributeDict["userRating"] ?? "0") ?? 0
      albumBuffer?.isFavorite = attributeDict["starred"] != nil
      if let attributeYear = attributeDict["year"], let year = Int(attributeYear) {
        albumBuffer?.year = year
      }
      if let attributeSongCount = attributeDict["songCount"],
         let songCount = Int(attributeSongCount) {
        albumBuffer?.remoteSongCount = songCount
      }
      if let attributeDuration = attributeDict["duration"], let duration = Int(attributeDuration) {
        albumBuffer?.remoteDuration = duration
      }

      if let artistId = attributeDict["artistId"] {
        if let guessedArtist = guessedArtist, guessedArtist.id == artistId {
          albumBuffer?.artist = guessedArtist
        } else if let artist = library.getArtist(id: artistId) {
          albumBuffer?.artist = artist
        } else if let artistName = attributeDict["artist"] {
          let artist = library.createArtist()
          artist.id = artistId
          artist.name = artistName
          os_log(
            "Artist <%s> with id %s has been created",
            log: log,
            type: .error,
            artistName,
            artistId
          )
          albumBuffer?.artist = artist
        }
      }

      if albumBuffer?.genre == nil, let genreName = attributeDict["genre"] {
        if let genre = library.getGenre(name: genreName) {
          albumBuffer?.genre = genre
        } else {
          let genre = library.createGenre()
          genre.name = genreName
          os_log("Genre <%s> has been created", log: log, type: .error, genreName)
          albumBuffer?.genre = genre
        }
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
    case "album":
      parsedCount += 1
      if let album = albumBuffer {
        parsedAlbums.append(album)
      }
      albumBuffer = nil
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
