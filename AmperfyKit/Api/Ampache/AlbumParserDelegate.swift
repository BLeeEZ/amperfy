//
//  AlbumParserDelegate.swift
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

class AlbumParserDelegate: AmpacheXmlLibParser {
  var albumBuffer: Album?
  var albumsParsedArray = [Album]()
  var albumsParsedSet: Set<Album> {
    Set(albumsParsedArray)
  }

  var artistIdToCreate: String?
  var genreIdToCreate: String?
  var rating: Int = 0

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
    case "album":
      guard let albumId = attributeDict["id"] else {
        os_log("Found album with no id", log: log, type: .error)
        return
      }
      if let fetchedAlbum = library.getAlbum(id: albumId, isDetailFaultResolution: true) {
        albumBuffer = fetchedAlbum
      } else {
        albumBuffer = library.createAlbum()
        albumBuffer?.id = albumId
      }
    case "artist":
      guard let album = albumBuffer, let artistId = attributeDict["id"] else { return }
      if let artist = library.getArtist(id: artistId) {
        album.artist = artist
      } else {
        artistIdToCreate = artistId
      }
    case "genre":
      if let album = albumBuffer {
        guard let genreId = attributeDict["id"] else { return }
        if let genre = library.getGenre(id: genreId) {
          album.genre = genre
        } else {
          genreIdToCreate = genreId
        }
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
    case "artist":
      if let artistId = artistIdToCreate {
        os_log("Artist <%s> with id %s has been created", log: log, type: .error, buffer, artistId)
        let artist = library.createArtist()
        artist.id = artistId
        artist.name = buffer
        albumBuffer?.artist = artist
        artistIdToCreate = nil
      }
    case "name":
      albumBuffer?.name = buffer
    case "album":
      parsedCount += 1
      albumBuffer?.rating = rating
      rating = 0
      if let parsedAlbum = albumBuffer {
        albumsParsedArray.append(parsedAlbum)
      }
      parseNotifier?.notifyParsedObject(ofType: .album)
      albumBuffer = nil
    case "rating":
      rating = Int(buffer) ?? 0
    case "flag":
      let flag = Int(buffer) ?? 0
      albumBuffer?.isFavorite = flag == 1 ? true : false
    case "year":
      albumBuffer?.year = Int(buffer) ?? 0
    case "time":
      albumBuffer?.remoteDuration = Int(buffer) ?? 0
    case "songcount":
      albumBuffer?.remoteSongCount = Int(buffer) ?? 0
    case "art":
      albumBuffer?.artwork = parseArtwork(urlString: buffer)
    case "genre":
      if let genreId = genreIdToCreate {
        os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
        let genre = library.createGenre()
        genre.id = genreId
        genre.name = buffer
        albumBuffer?.genre = genre
        genreIdToCreate = nil
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
