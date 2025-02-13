//
//  CatalogParserDelegate.swift
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

import CoreData
import Foundation
import os.log
import UIKit

class CatalogParserDelegate: AmpacheXmlLibParser {
  let musicFoldersBeforeFetch: Set<MusicFolder>
  var musicFoldersParsed = Set<MusicFolder>()
  var musicFolderBuffer: MusicFolder?

  init(performanceMonitor: ThreadPerformanceMonitor, library: LibraryStorage) {
    self.musicFoldersBeforeFetch = Set(library.getMusicFolders())
    super.init(performanceMonitor: performanceMonitor, library: library)
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

    if elementName == "catalog" {
      guard let id = attributeDict["id"] else {
        os_log("Found catalog with no id", log: log, type: .error)
        return
      }
      if let fetchedMusicFolder = library.getMusicFolder(id: id) {
        musicFolderBuffer = fetchedMusicFolder
      } else {
        musicFolderBuffer = library.createMusicFolder()
        musicFolderBuffer?.id = id
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
      musicFolderBuffer?.name = buffer
    case "catalog":
      parsedCount += 1
      if let parsedmusicFolder = musicFolderBuffer {
        musicFoldersParsed.insert(parsedmusicFolder)
      }
      musicFolderBuffer = nil
    case "root":
      let removedMusicFolders = musicFoldersBeforeFetch.subtracting(musicFoldersParsed)
      removedMusicFolders.forEach { library.deleteMusicFolder(musicFolder: $0) }
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
