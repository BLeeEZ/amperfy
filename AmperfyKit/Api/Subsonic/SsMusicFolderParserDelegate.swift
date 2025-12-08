//
//  SsMusicFolderParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import os.log

class SsMusicFolderParserDelegate: SsXmlLibParser {
  let musicFoldersBeforeFetch: Set<MusicFolder>
  private var musicFoldersDict: [String: MusicFolder]
  var musicFoldersParsed = Set<MusicFolder>()

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.musicFoldersBeforeFetch = Set(library.getMusicFolders(for: account))
    self.musicFoldersDict = [String: MusicFolder]()
    for mf in musicFoldersBeforeFetch {
      musicFoldersDict[mf.id] = mf
    }
    super.init(
      performanceMonitor: performanceMonitor,
      prefetch: prefetch,
      account: account,
      library: library
    )
  }

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

    if elementName == "musicFolder", let id = attributeDict["id"],
       let name = attributeDict["name"] {
      if let musicFolder = musicFoldersDict[id] {
        musicFoldersParsed.insert(musicFolder)
      } else {
        let musicFolder = library.createMusicFolder(account: account)
        musicFolder.id = id
        musicFolder.name = name
        musicFoldersDict[id] = musicFolder
        musicFoldersParsed.insert(musicFolder)
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "musicFolders" {
      let removedMusicFolders = musicFoldersBeforeFetch.subtracting(musicFoldersParsed)
      removedMusicFolders.forEach { library.deleteMusicFolder(musicFolder: $0) }
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
