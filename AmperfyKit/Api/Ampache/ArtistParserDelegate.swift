//
//  ArtistParserDelegate.swift
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

class ArtistParserDelegate: AmpacheXmlLibParser {
  var artistsParsed = Set<Artist>()
  var artistBuffer: Artist?
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

    if elementName == "artist" {
      guard let artistId = attributeDict["id"] else {
        os_log("Found artist with no id", log: log, type: .error)
        return
      }
      if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
        artistBuffer = prefetchedArtist
      } else {
        artistBuffer = library.createArtist(account: account)
        artistBuffer?.id = artistId
      }
    }
    if elementName == "genre", let artist = artistBuffer {
      guard let genreId = attributeDict["id"] else { return }
      if let prefetchedGenre = prefetch.prefetchedGenreDict[genreId] {
        artist.genre = prefetchedGenre
      } else {
        genreIdToCreate = genreId
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
    case "name":
      artistBuffer?.name = buffer
    case "rating":
      rating = Int(buffer) ?? 0
    case "flag":
      let flag = Int(buffer) ?? 0
      artistBuffer?.isFavorite = flag == 1 ? true : false
    case "albumcount":
      artistBuffer?.remoteAlbumCount = Int(buffer) ?? 0
    case "time":
      artistBuffer?.remoteDuration = Int(buffer) ?? 0
    case "genre":
      if let genreId = genreIdToCreate {
        os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
        let genre = library.createGenre(account: account)
        prefetch.prefetchedGenreDict[genreId] = genre
        genre.id = genreId
        genre.name = buffer
        artistBuffer?.genre = genre
        genreIdToCreate = nil
      }
    case "art":
      artistBuffer?.artwork = parseArtwork(urlString: buffer)
    case "artist":
      parsedCount += 1
      parseNotifier?.notifyParsedObject(ofType: .artist)
      artistBuffer?.rating = rating
      rating = 0
      if let parsedArtist = artistBuffer {
        artistsParsed.insert(parsedArtist)
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
