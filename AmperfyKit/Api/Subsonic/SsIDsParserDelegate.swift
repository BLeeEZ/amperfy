//
//  SsIDsParserDelegate.swift
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
import os.log
import UIKit

class SsIDsParserDelegate: SsNotifiableXmlParser {
  public private(set) var prefetchIDs = LibraryStorage.PrefetchIdContainer()
  private var isIndex = false

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

    if elementName == "indexes" {
      isIndex = true
    }

    var isDirectory = false
    if elementName == "child", let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir),
       isDirBool {
      isDirectory = true
    }

    if let id = attributeDict["id"] {
      if elementName == "song" || elementName == "entry" || elementName == "child" || elementName ==
        "episode" {
        if isDirectory {
          prefetchIDs.directoryIDs.insert(id)
        } else if elementName == "episode" {
          prefetchIDs.podcastEpisodeIDs.insert(id)
        } else {
          prefetchIDs.songIDs.insert(id)
        }
      } else if elementName == "album" {
        prefetchIDs.albumIDs.insert(id)
      } else if elementName == "artist" {
        if isIndex {
          prefetchIDs.directoryIDs.insert(id)
        } else {
          prefetchIDs.artistIDs.insert(id)
        }
      } else if elementName == "musicFolder" {
        prefetchIDs.musicFolderIDs.insert(id)
      } else if elementName == "channel" {
        prefetchIDs.podcastIDs.insert(id)
      } else if elementName == "internetRadioStation" {
        prefetchIDs.radioIDs.insert(id)
      }
    }

    if let artistId = attributeDict["artistId"] {
      prefetchIDs.artistIDs.insert(artistId)
    } else if !isIndex || elementName == "child", !isDirectory,
              let artistName = attributeDict["artist"] {
      prefetchIDs.localArtistNames.insert(artistName)
    }

    if let albumId = attributeDict["albumId"] {
      prefetchIDs.albumIDs.insert(albumId)
    }

    if let coverArtId = attributeDict["coverArt"] {
      let remoteInfo = ArtworkRemoteInfo(id: coverArtId, type: "")
      prefetchIDs.artworkIDs.insert(remoteInfo)
    }

    if elementName != "episode", let genreName = attributeDict["genre"] {
      // ignore podcast episode genre
      prefetchIDs.genreNames.insert(genreName)
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "indexes" {
      isIndex = false
    } else if elementName == "genre" {
      prefetchIDs.genreNames.insert(buffer)
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
