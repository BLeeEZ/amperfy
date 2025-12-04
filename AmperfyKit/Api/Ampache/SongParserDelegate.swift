//
//  SongParserDelegate.swift
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

class SongParserDelegate: PlayableParserDelegate {
  var songBuffer: Song?
  var parsedSongs = [Song]()
  var artistIdToCreate: String?
  var albumIdToCreate: String?
  var genreIdToCreate: String?

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
    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )

    switch elementName {
    case "song":
      guard let songId = attributeDict["id"] else {
        os_log("Found song with no id", log: log, type: .error)
        return
      }
      if let prefetchedSong = prefetch.prefetchedSongDict[songId] {
        songBuffer = prefetchedSong
        songBuffer?.remoteStatus = .available
        guessedArtist = prefetchedSong.artist
        guessedAlbum = prefetchedSong.album
        guessedGenre = prefetchedSong.genre
      } else {
        songBuffer = library.createSong(account: account)
        songBuffer?.id = songId
        prefetch.prefetchedSongDict[songId] = songBuffer
        guessedArtist = nil
        guessedAlbum = nil
        guessedGenre = nil
      }
      playableBuffer = songBuffer
    case "artist":
      guard let song = songBuffer, let artistId = attributeDict["id"] else { return }
      if let guessedArtist, guessedArtist.id == artistId {
        song.artist = guessedArtist
      } else if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
        song.artist = prefetchedArtist
      } else {
        artistIdToCreate = artistId
      }
    case "album":
      guard let song = songBuffer, let albumId = attributeDict["id"] else { return }
      if let guessedAlbum, guessedAlbum.id == albumId {
        song.album = guessedAlbum
      } else if let prefetchedAlbum = prefetch.prefetchedAlbumDict[albumId] {
        song.album = prefetchedAlbum
      } else {
        albumIdToCreate = albumId
      }
    case "genre":
      guard let song = songBuffer, let genreId = attributeDict["id"] else { return }
      if let guessedGenre = guessedGenre, guessedGenre.id == genreId {
        song.genre = guessedGenre
      } else if let prefetchedGenre = prefetch.prefetchedGenreDict[genreId] {
        song.genre = prefetchedGenre
      } else {
        genreIdToCreate = genreId
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
        let artist = library.createArtist(account: account)
        prefetch.prefetchedArtistDict[artistId] = artist
        artist.id = artistId
        artist.name = buffer
        songBuffer?.artist = artist
        artistIdToCreate = nil
      }
    case "album":
      if let albumId = albumIdToCreate {
        os_log("Album <%s> with id %s has been created", log: log, type: .error, buffer, albumId)
        let album = library.createAlbum(account: account)
        prefetch.prefetchedAlbumDict[albumId] = album
        album.id = albumId
        album.name = buffer
        songBuffer?.album = album
        albumIdToCreate = nil
      }
    case "genre":
      if let genreId = genreIdToCreate {
        os_log("Genre <%s> with id %s has been created", log: log, type: .error, buffer, genreId)
        let genre = library.createGenre(account: account)
        prefetch.prefetchedGenreDict[genreId] = genre
        genre.id = genreId
        genre.name = buffer
        songBuffer?.genre = genre
        genreIdToCreate = nil
      }
    case "song":
      parsedCount += 1
      parseNotifier?.notifyParsedObject(ofType: .song)
      songBuffer?.rating = rating
      rating = 0
      resetPlayableBuffer()
      if let song = songBuffer {
        parsedSongs.append(song)
      }
      songBuffer = nil
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
