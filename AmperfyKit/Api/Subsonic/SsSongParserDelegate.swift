//
//  SsSongParserDelegate.swift
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

class SsSongParserDelegate: SsPlayableParserDelegate {
  var songBuffer: Song?
  var parsedSongs = [Song]()
  var guessedArtist: Artist?
  var guessedAlbum: Album?
  var guessedGenre: Genre?

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    if elementName == "song" || elementName == "entry" || elementName == "child" || elementName ==
      "episode" {
      guard let songId = attributeDict["id"] else { return }
      let isDir = attributeDict["isDir"] ?? "false"
      guard let isDirBool = Bool(isDir), isDirBool == false else { return }

      if let fetchedSong = library.getSong(id: songId) {
        songBuffer = fetchedSong
        songBuffer?.remoteStatus = .available
      } else {
        songBuffer = library.createSong()
        songBuffer?.id = songId
      }
      playableBuffer = songBuffer

      if let artistId = attributeDict["artistId"] {
        if let guessedArtist = guessedArtist, guessedArtist.id == artistId {
          songBuffer?.artist = guessedArtist
          songBuffer?.artist?.remoteStatus = .available
        } else if let artist = library.getArtist(id: artistId) {
          songBuffer?.artist = artist
          songBuffer?.artist?.remoteStatus = .available
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
          songBuffer?.artist = artist
        }
      } else if let songBuffer = songBuffer, let artistName = attributeDict["artist"] {
        if let existingLocalArtist = library.getArtistLocal(name: artistName) {
          songBuffer.artist = existingLocalArtist
        } else {
          let artist = library.createArtist()
          artist.name = artistName
          songBuffer.artist = artist
          os_log("Local Artist <%s> has been created (no id)", log: log, type: .error, artistName)
        }
      }

      if let albumId = attributeDict["albumId"] {
        if let guessedAlbum = guessedAlbum, guessedAlbum.id == albumId {
          songBuffer?.album = guessedAlbum
          songBuffer?.album?.remoteStatus = .available
        } else if let album = library.getAlbum(id: albumId, isDetailFaultResolution: true) {
          songBuffer?.album = album
          songBuffer?.album?.remoteStatus = .available
        } else if let albumName = attributeDict["album"] {
          let album = library.createAlbum()
          album.id = albumId
          album.name = albumName
          os_log(
            "Album <%s> with id %s has been created",
            log: log,
            type: .error,
            albumName,
            albumId
          )
          songBuffer?.album = album
        }
      }

      if let genreName = attributeDict["genre"] {
        if let guessedGenre = guessedGenre, guessedGenre.name == genreName {
          songBuffer?.genre = guessedGenre
        } else if let genre = library.getGenre(name: genreName) {
          songBuffer?.genre = genre
        } else {
          let genre = library.createGenre()
          genre.name = genreName
          os_log("Genre <%s> has been created", log: log, type: .error, genreName)
          songBuffer?.genre = genre
        }
      }
    }

    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "song" || elementName == "entry" || elementName == "child" || elementName ==
      "episode", songBuffer != nil {
      parsedCount += 1
      resetPlayableBuffer()
      if let song = songBuffer {
        parsedSongs.append(song)
      }
      songBuffer = nil
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
