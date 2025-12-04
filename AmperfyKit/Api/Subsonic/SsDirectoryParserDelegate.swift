//
//  SsDirectoryParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.05.21.
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

class SsDirectoryParserDelegate: SsSongParserDelegate {
  let directory: Directory?
  let musicFolder: MusicFolder?

  let directoriesBeforeFetch: Set<Directory>
  var directoriesParsed = Set<Directory>()
  let songsBeforeFetch: Set<Song>
  var songsParsed = Set<Song>()

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    directory: Directory,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.directory = directory
    self.musicFolder = nil
    self.directoriesBeforeFetch = Set(directory.subdirectories)
    self.songsBeforeFetch = Set(directory.songs)
    super.init(
      performanceMonitor: performanceMonitor,
      prefetch: prefetch,
      account: account,
      library: library
    )
  }

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    musicFolder: MusicFolder,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.directory = nil
    self.musicFolder = musicFolder
    self.directoriesBeforeFetch = Set(musicFolder.directories)
    self.songsBeforeFetch = Set(musicFolder.songs)
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

    if elementName == "child" {
      if let isDir = attributeDict["isDir"], let isDirBool = Bool(isDir), isDirBool {
        if let id = attributeDict["id"], let title = attributeDict["title"] {
          var parsedDirectory: Directory!
          if let prefetchedDirectory = prefetch.prefetchedDirectoryDict[id] {
            parsedDirectory = prefetchedDirectory
          } else {
            parsedDirectory = library.createDirectory(account: account)
            prefetch.prefetchedDirectoryDict[id] = parsedDirectory
            parsedDirectory.id = id
            parsedDirectory.name = title
            if let coverArtId = attributeDict["coverArt"] {
              parsedDirectory.artwork = parseArtwork(id: coverArtId)
            }
          }

          if let directory = directory {
            directory.managedObject.addToSubdirectories(parsedDirectory.managedObject)
          } else if let musicFolder = musicFolder {
            musicFolder.managedObject.addToDirectories(parsedDirectory.managedObject)
          }
          directoriesParsed.insert(parsedDirectory)
        }
      } else if let song = songBuffer {
        if let directory = directory {
          directory.managedObject.addToSongs(song.managedObject)
          songsParsed.insert(song)
        } else if let musicFolder = musicFolder {
          musicFolder.managedObject.addToSongs(song.managedObject)
          songsParsed.insert(song)
        }
      }
    }
    if elementName == "artist" {
      if let id = attributeDict["id"], let name = attributeDict["name"] {
        var parsedDirectory: Directory!
        if let prefetchedDirectory = prefetch.prefetchedDirectoryDict[id] {
          parsedDirectory = prefetchedDirectory
        } else {
          parsedDirectory = library.createDirectory(account: account)
          prefetch.prefetchedDirectoryDict[id] = parsedDirectory
          parsedDirectory.id = id
          parsedDirectory.name = name
        }

        if let directory = directory {
          directory.managedObject.addToSubdirectories(parsedDirectory.managedObject)
        } else if let musicFolder = musicFolder {
          musicFolder.managedObject.addToDirectories(parsedDirectory.managedObject)
        }
        directoriesParsed.insert(parsedDirectory)
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "indexes" || elementName == "directory" {
      let removedDirectories = directoriesBeforeFetch.subtracting(directoriesParsed)
      removedDirectories.forEach { library.deleteDirectory(directory: $0) }

      if let directory = directory {
        let removedSongs = songsBeforeFetch.subtracting(songsParsed)
        removedSongs.forEach { directory.managedObject.removeFromSongs($0.managedObject) }
        directory.isCached = isCollectionCached
      } else if let musicFolder = musicFolder {
        let removedSongs = songsBeforeFetch.subtracting(songsParsed)
        removedSongs.forEach { musicFolder.managedObject.removeFromSongs($0.managedObject) }
        musicFolder.isCached = isCollectionCached
      }
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
