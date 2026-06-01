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
  // Accumulates individual artist names from OpenSubsonic <artists> child elements.
  var collectedMultiArtists = [Artist]()
  // Accumulates album artist entities from OpenSubsonic <albumArtists> child elements.
  var collectedAlbumArtists = [Artist]()
  // Accumulates genre entities from OpenSubsonic <genres name="..."/> child elements.
  var collectedMultiGenres = [Genre]()
  // Accumulates contributors from OpenSubsonic <contributors role="..."><artist .../></contributors>.
  var collectedContributors = [(role: String, subRole: String, name: String)]()
  var currentContributorRole = ""
  var currentContributorSubRole = ""
  var isInsideContributor = false
  // For text-content child elements (isrc, moods, groupings).
  var currentTextElementName = ""
  var currentTextBuffer = ""
  var collectedISRCs = [String]()
  var collectedMoods = [String]()
  var collectedGroupings = [String]()

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

      if let prefetchedSong = prefetch.prefetchedSongDict[songId] {
        songBuffer = prefetchedSong
        songBuffer?.remoteStatus = .available
        guessedArtist = prefetchedSong.artist
        guessedAlbum = prefetchedSong.album
        guessedGenre = prefetchedSong.genre
      } else {
        songBuffer = library.createSong(account: account)
        prefetch.prefetchedSongDict[songId] = songBuffer
        songBuffer?.id = songId
        guessedArtist = nil
        guessedAlbum = nil
        guessedGenre = nil
      }
      playableBuffer = songBuffer

      if let artistId = attributeDict["artistId"] {
        if let guessedArtist, guessedArtist.id == artistId {
          songBuffer?.artist = guessedArtist
          songBuffer?.artist?.remoteStatus = .available
        } else if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
          songBuffer?.artist = prefetchedArtist
          songBuffer?.artist?.remoteStatus = .available
        } else if let artistName = attributeDict["artist"] {
          let artist = library.createArtist(account: account)
          prefetch.prefetchedArtistDict[artistId] = artist
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
        if let guessedArtist, guessedArtist.name == artistName {
          songBuffer.artist = guessedArtist
        } else if let prefetchedArtist = prefetch.prefetchedLocalArtistDict[artistName] {
          songBuffer.artist = prefetchedArtist
        } else {
          let artist = library.createArtist(account: account)
          prefetch.prefetchedLocalArtistDict[artistName] = artist
          artist.name = artistName
          songBuffer.artist = artist
          os_log("Local Artist <%s> has been created (no id)", log: log, type: .error, artistName)
        }
      }

      collectedMultiArtists = []
      collectedAlbumArtists = []
      collectedMultiGenres = []
      collectedContributors = []
      collectedISRCs = []
      collectedMoods = []
      collectedGroupings = []
      isInsideContributor = false
      currentTextElementName = ""
      currentTextBuffer = ""

      // OpenSubsonic simple-attribute fields
      if let bpmStr = attributeDict["bpm"], let bpmVal = Int(bpmStr) {
        songBuffer?.bpm = bpmVal
      }
      if let commentStr = attributeDict["comment"] {
        songBuffer?.comment = commentStr.isEmpty ? nil : commentStr
      }
      if let sortNameStr = attributeDict["sortName"] {
        songBuffer?.sortName = sortNameStr.isEmpty ? nil : sortNameStr
      }
      if let mbidStr = attributeDict["musicBrainzId"] {
        songBuffer?.musicBrainzId = mbidStr.isEmpty ? nil : mbidStr
      }
      if let displayAlbumArtistStr = attributeDict["displayAlbumArtist"] {
        songBuffer?.displayAlbumArtist =
          displayAlbumArtistStr.isEmpty ? nil : displayAlbumArtistStr
      }
      if let displayComposerStr = attributeDict["displayComposer"] {
        songBuffer?.displayComposer = displayComposerStr.isEmpty ? nil : displayComposerStr
      }
      if let explicitStatusStr = attributeDict["explicitStatus"] {
        songBuffer?.explicitStatus = explicitStatusStr.isEmpty ? nil : explicitStatusStr
      }
      if let channelStr = attributeDict["channelCount"], let channelVal = Int(channelStr) {
        songBuffer?.channelCount = channelVal
      }
      if let srStr = attributeDict["samplingRate"], let srVal = Int(srStr) {
        songBuffer?.samplingRate = srVal
      }
      if let bdStr = attributeDict["bitDepth"], let bdVal = Int(bdStr) {
        songBuffer?.bitDepth = bdVal
      }

      if let albumId = attributeDict["albumId"] {
        if let guessedAlbum, guessedAlbum.id == albumId {
          songBuffer?.album = guessedAlbum
          songBuffer?.album?.remoteStatus = .available
        } else if let prefetchedAlbum = prefetch.prefetchedAlbumDict[albumId] {
          songBuffer?.album = prefetchedAlbum
          songBuffer?.album?.remoteStatus = .available
        } else if let albumName = attributeDict["album"] {
          let album = library.createAlbum(account: account)
          prefetch.prefetchedAlbumDict[albumId] = album
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
        if let guessedGenre, guessedGenre.name == genreName {
          songBuffer?.genre = guessedGenre
        } else if let prefetchedGenre = prefetch.prefetchedGenreDict[genreName] {
          songBuffer?.genre = prefetchedGenre
        } else {
          let genre = library.createGenre(account: account)
          prefetch.prefetchedGenreDict[genreName] = genre
          genre.name = genreName
          os_log("Genre <%s> has been created", log: log, type: .error, genreName)
          songBuffer?.genre = genre
        }
      }
      if let createdTag = attributeDict["created"] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        songBuffer?.addedDate = dateFormatter.date(from: createdTag)
      }
    }

    // Each OpenSubsonic song artist is its own <artists id="..." name="..."/> element.
    // Look up or create the Artist entity and collect it.
    if elementName == "artists", songBuffer != nil {
      if let artistId = attributeDict["id"] {
        if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
          collectedMultiArtists.append(prefetchedArtist)
        } else if let artistName = attributeDict["name"] {
          let artist = library.createArtist(account: account)
          prefetch.prefetchedArtistDict[artistId] = artist
          artist.id = artistId
          artist.name = artistName
          os_log("Multi-artist <%s> id %s created", log: log, type: .error, artistName, artistId)
          collectedMultiArtists.append(artist)
        }
      }
    }

    // Album artists: <albumArtists id="..." name="..."/>
    if elementName == "albumArtists", songBuffer != nil {
      if let artistId = attributeDict["id"] {
        if let prefetchedArtist = prefetch.prefetchedArtistDict[artistId] {
          collectedAlbumArtists.append(prefetchedArtist)
        } else if let artistName = attributeDict["name"] {
          let artist = library.createArtist(account: account)
          prefetch.prefetchedArtistDict[artistId] = artist
          artist.id = artistId
          artist.name = artistName
          os_log("Album artist <%s> id %s created", log: log, type: .error, artistName, artistId)
          collectedAlbumArtists.append(artist)
        }
      }
    }

    // Multi-genre: <genres name="..."/> (no ID in OpenSubsonic, keyed by name)
    if elementName == "genres", songBuffer != nil, let name = attributeDict["name"],
       !name.isEmpty {
      if let prefetchedGenre = prefetch.prefetchedGenreDict[name] {
        collectedMultiGenres.append(prefetchedGenre)
      } else {
        let genre = library.createGenre(account: account)
        prefetch.prefetchedGenreDict[name] = genre
        genre.name = name
        os_log("Multi-genre <%s> created", log: log, type: .error, name)
        collectedMultiGenres.append(genre)
      }
    }

    // Contributors: <contributors role="..." subRole="..."><artist id="..." name="..."/></contributors>
    if elementName == "contributors", songBuffer != nil {
      currentContributorRole = attributeDict["role"] ?? ""
      currentContributorSubRole = attributeDict["subRole"] ?? ""
      isInsideContributor = true
    }
    // Inner <artist> element inside a <contributors> block
    if elementName == "artist", isInsideContributor, let name = attributeDict["name"],
       !name.isEmpty {
      collectedContributors.append(
        (role: currentContributorRole, subRole: currentContributorSubRole, name: name)
      )
    }

    // Text-content child elements: <isrc>, <moods>, <groupings>
    if elementName == "isrc" || elementName == "moods" || elementName == "groupings",
       songBuffer != nil {
      currentTextElementName = elementName
      currentTextBuffer = ""
    }

    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )
  }

  override func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard !currentTextElementName.isEmpty, songBuffer != nil else { return }
    currentTextBuffer += string
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    // Finalise text-content child elements
    if elementName == currentTextElementName, !currentTextElementName.isEmpty {
      let trimmed = currentTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        switch currentTextElementName {
        case "isrc": collectedISRCs.append(trimmed)
        case "moods": collectedMoods.append(trimmed)
        case "groupings": collectedGroupings.append(trimmed)
        default: break
        }
      }
      currentTextElementName = ""
      currentTextBuffer = ""
    }

    // Contributors block ends
    if elementName == "contributors" {
      isInsideContributor = false
    }

    if elementName == "song" || elementName == "entry" || elementName == "child" || elementName ==
      "episode", songBuffer != nil {
      // Multi-artist entities
      if !collectedMultiArtists.isEmpty {
        songBuffer?.multiArtists = collectedMultiArtists
      }

      // Album artist entities
      if !collectedAlbumArtists.isEmpty {
        songBuffer?.albumArtists = collectedAlbumArtists
      }

      // Multi-genre entities
      if !collectedMultiGenres.isEmpty {
        songBuffer?.multiGenres = collectedMultiGenres
      }

      // ISRC list
      if !collectedISRCs.isEmpty {
        songBuffer?.isrcList = collectedISRCs.joined(separator: ", ")
      }

      // Moods list
      if !collectedMoods.isEmpty {
        songBuffer?.moodsList = collectedMoods.joined(separator: ", ")
      }

      // Groupings list
      if !collectedGroupings.isEmpty {
        songBuffer?.groupingsList = collectedGroupings.joined(separator: ", ")
      }

      // Contributors: group by role, format as "Role: Name1, Name2"
      if !collectedContributors.isEmpty {
        var roleGroups = [String: [String]]()
        var roleOrder = [String]()
        for contributor in collectedContributors {
          let roleLabel = contributor.subRole.isEmpty
            ? contributor.role.capitalized
            : "\(contributor.role.capitalized) (\(contributor.subRole))"
          if roleGroups[roleLabel] == nil {
            roleGroups[roleLabel] = []
            roleOrder.append(roleLabel)
          }
          roleGroups[roleLabel]?.append(contributor.name)
        }
        let lines = roleOrder.compactMap { role -> String? in
          guard let names = roleGroups[role], !names.isEmpty else { return nil }
          return "\(role): \(names.joined(separator: ", "))"
        }
        songBuffer?.contributorsString = lines.joined(separator: "\n")
      }

      collectedMultiArtists = []
      collectedAlbumArtists = []
      collectedMultiGenres = []
      collectedContributors = []
      collectedISRCs = []
      collectedMoods = []
      collectedGroupings = []
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
