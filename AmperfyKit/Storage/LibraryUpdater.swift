//
//  LibraryUpdater.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.06.21.
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

// MARK: - LibraryUpdaterCallbacks

public protocol LibraryUpdaterCallbacks: Sendable {
  func startOperation(name: String, totalCount: Int)
  func tickOperation()
}

// MARK: - UpdateHelper

public class UpdateHelper {
  public func moveArtworkToFileManager(
    artworkRemoteInfo: ArtworkRemoteInfo,
    asyncCompanion: CoreDataCompanion
  ) {
    autoreleasepool {
      if let imageData = asyncCompanion.library
        .getArtworkData(forArtworkRemoteInfo: artworkRemoteInfo),
        let artwork = asyncCompanion.library.getArtwork(remoteInfo: artworkRemoteInfo),
        let relFilePath = CacheFileManager.shared.createRelPath(for: artworkRemoteInfo),
        let absFilePath = CacheFileManager.shared
        .getAbsoluteAmperfyPath(relFilePath: relFilePath) {
        do {
          try CacheFileManager.shared.writeDataExcludedFromBackup(data: imageData, to: absFilePath)
          artwork.relFilePath = relFilePath
        } catch {
          artwork.relFilePath = nil
        }
        artwork.managedObject.imageData = nil
      }
    }
  }

  public func moveEmbeddedArtworkToFileManager(
    embeddedArtworkOwner: AbstractPlayable,
    asyncCompanion: CoreDataCompanion
  ) {
    autoreleasepool {
      if let imageData = asyncCompanion.library
        .getEmbeddedArtworkData(forOwner: embeddedArtworkOwner),
        let embeddedArtwork = asyncCompanion.library
        .getEmbeddedArtwork(forOwner: embeddedArtworkOwner),
        let relFilePath = CacheFileManager.shared.createRelPath(for: embeddedArtwork),
        let absFilePath = CacheFileManager.shared
        .getAbsoluteAmperfyPath(relFilePath: relFilePath) {
        do {
          try CacheFileManager.shared.writeDataExcludedFromBackup(data: imageData, to: absFilePath)
          embeddedArtwork.relFilePath = relFilePath
        } catch {
          embeddedArtwork.relFilePath = nil
        }
        embeddedArtwork.managedObject.imageData = nil
      }
    }
  }

  public func movePlayableToFileManager(
    playable: AbstractPlayable,
    asyncCompanion: CoreDataCompanion
  ) {
    if let playableData = getPlayableDataAndDeleteCoreDataFile(
      playable: playable,
      asyncCompanion: asyncCompanion
    ) {
      movePlayableToFileManager(playable: playable, fileData: playableData)
    }
  }

  public func getPlayableDataAndDeleteCoreDataFile(
    playable: AbstractPlayable,
    asyncCompanion: CoreDataCompanion
  )
    -> Data? {
    var data: Data?
    autoreleasepool {
      if let playableFile = asyncCompanion.library.getFile(forPlayable: playable) {
        let playableFileSizeInByte = asyncCompanion.library
          .getFileSizeOfPlayableFileInByte(playableFile: playableFile)
        // file size must be smaller than 1 GB
        // file data will be loaded into memory -> too big will lead to crash
        if playableFileSizeInByte < 1_000_000_000 {
          data = playableFile.data
        }
        playableFile.info?.playableManagedObject.file = nil
        asyncCompanion.library.deletePlayableFile(playableFile: playableFile)
      }
    }
    return data
  }

  public func movePlayableToFileManager(playable: AbstractPlayable, fileData: Data) {
    if let relFilePath = CacheFileManager.shared.createRelPath(for: playable),
       let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
      do {
        try CacheFileManager.shared.writeDataExcludedFromBackup(data: fileData, to: absFilePath)
        playable.relFilePath = relFilePath
      } catch {
        playable.relFilePath = nil
      }
    }
  }
}

// MARK: - LibraryUpdater

public class LibraryUpdater {
  private static let sleepTimeInMicroSecToReduceCpuLoad: UInt32 = 500

  @MainActor
  private let log = OSLog(subsystem: "Amperfy", category: "BackgroundSyncer")
  private let storage: PersistentStorage
  private let backendApi: BackendApi
  private let fileManager = CacheFileManager.shared

  init(storage: PersistentStorage, backendApi: BackendApi) {
    self.storage = storage
    self.backendApi = backendApi
  }

  public var isVisualUpadateNeeded: Bool {
    storage.librarySyncVersion != .newestVersion
  }

  /// This function will block the execution before the scene handler
  /// Perform here only small/fast operations
  /// Use UpdateVC for longer operations to display progress to user
  @MainActor
  public func performSmallBlockingLibraryUpdatesIfNeeded() {
    if storage.librarySyncVersion < .v9 {
      os_log("Perform blocking library update (START): Artwork ids", log: log, type: .info)
      updateArtworkIdStructure()
      os_log("Perform blocking library update (DONE): Artwork ids", log: log, type: .info)
    }
    if storage.librarySyncVersion < .v12 {
      os_log(
        "Perform blocking library update (START): alphabeticSectionInitial",
        log: log,
        type: .info
      )
      updateAlphabeticSectionInitial()
      os_log(
        "Perform blocking library update (DONE): alphabeticSectionInitial",
        log: log,
        type: .info
      )
    }
    if storage.librarySyncVersion < .v13 {
      storage
        .librarySyncVersion =
        .v13 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): AbstractPlayable.duration",
        log: log,
        type: .info
      )
      // no updated needed anymore
      os_log(
        "Perform blocking library update (DONE): AbstractPlayable.duration",
        log: log,
        type: .info
      )
    }
    if storage.librarySyncVersion < .v15 {
      storage
        .librarySyncVersion =
        .v15 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Artist,Album,Playlist duration,remoteSongCount",
        log: log,
        type: .info
      )
      // no updated needed anymore
      os_log(
        "Perform blocking library update (DONE): Artist,Album,Playlist duration,remoteSongCount",
        log: log,
        type: .info
      )
    }
    if storage.librarySyncVersion < .v16 {
      storage
        .librarySyncVersion =
        .v16 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Playlist artworkItems",
        log: log,
        type: .info
      )
      updatePlaylistArtworkItems()
      os_log("Perform blocking library update (DONE): Playlist artworkItems", log: log, type: .info)
    }
  }

  private var isRunning = true

  public func cancleLibraryUpdate() {
    os_log("LibraryUpdate: cancle", log: self.log, type: .info)
    isRunning = false
  }

  @MainActor
  public func performLibraryUpdateWithStatus(
    notifier: LibraryUpdaterCallbacks
  ) async throws {
    isRunning = true
    if storage.librarySyncVersion < .v17 {
      storage
        .librarySyncVersion =
        .v17 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Extract Binary Data",
        log: self.log,
        type: .info
      )
      try await extractBinaryDataToFileManager(notifier: notifier)
      os_log(
        "Perform blocking library update (DONE): Extract  Binary Data",
        log: self.log,
        type: .info
      )
    }
    if storage.librarySyncVersion < .v18 {
      // add radios to libraryDisplaySettings to display it for old users
      var libraryDisplaySettingsInUse = storage.settings.libraryDisplaySettings.inUse
      libraryDisplaySettingsInUse.append(.radios)
      storage.settings
        .libraryDisplaySettings = LibraryDisplaySettings(inUse: libraryDisplaySettingsInUse)

      storage
        .librarySyncVersion =
        .v18 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Denormalization Count",
        log: self.log,
        type: .info
      )
      try await denormalizeCount(notifier: notifier)
      os_log(
        "Perform blocking library update (DONE): Denormalization Count",
        log: self.log,
        type: .info
      )
    }
    if storage.librarySyncVersion < .v19 {
      storage
        .librarySyncVersion =
        .v19 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Sort playlist items",
        log: self.log,
        type: .info
      )
      try await sortPlaylistItems(notifier: notifier)
      os_log(
        "Perform blocking library update (DONE): Sort playlist items",
        log: self.log,
        type: .info
      )
    }
  }

  @MainActor
  private func updateArtworkIdStructure() {
    // Extract artwork info from URL
    var artworks = storage.main.library.getArtworks()
    for artwork in artworks {
      if let artworkUrlInfo = backendApi.extractArtworkInfoFromURL(urlString: artwork.url) {
        artwork.type = artworkUrlInfo.type
        artwork.id = artworkUrlInfo.id
      } else {
        storage.main.library.deleteArtwork(artwork: artwork)
      }
    }
    storage.main.saveContext()

    // Delete duplicate artworks
    artworks = storage.main.library.getArtworks()
    var uniqueArtworks: [String: Artwork] = [:]
    for artwork in artworks {
      if let existingArtwork = uniqueArtworks[artwork.uniqueID] {
        artwork.owners.forEach { $0.artwork = existingArtwork }
        storage.main.library.deleteArtwork(artwork: artwork)
      } else {
        uniqueArtworks[artwork.uniqueID] = artwork
      }
    }
    storage.main.saveContext()
  }

  @MainActor
  private func updateAlphabeticSectionInitial() {
    os_log("Library update: Genres", log: log, type: .info)
    let genres = storage.main.library.getGenres()
    genres.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Artists", log: log, type: .info)
    let artists = storage.main.library.getArtists()
    artists.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Albums", log: log, type: .info)
    let albums = storage.main.library.getAlbums()
    albums.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Songs", log: log, type: .info)
    let songs = storage.main.library.getSongs()
    songs.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Podcasts", log: log, type: .info)
    let podcasts = storage.main.library.getPodcasts()
    podcasts.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: PodcastEpisodes", log: log, type: .info)
    let podcastEpisodes = storage.main.library.getPodcastEpisodes()
    podcastEpisodes.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Directories", log: log, type: .info)
    let directories = storage.main.library.getDirectories()
    directories.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Playlists", log: log, type: .info)
    let playlists = storage.main.library.getPlaylists()
    playlists.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    storage.main.saveContext()
  }

  @MainActor
  private func updatePlaylistArtworkItems() {
    let playlists = storage.main.library.getPlaylists()
    playlists.forEach {
      $0.updateArtworkItems()
    }
    storage.main.saveContext()
  }

  @MainActor
  private func extractBinaryDataToFileManager(
    notifier: LibraryUpdaterCallbacks
  ) async throws {
    // To avoid crashed due to RAM overflow we need to use
    // autoreleasepool: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html

    os_log(
      "Perform blocking library update (START): Extract Binary Data",
      log: self.log,
      type: .info
    )
    try await storage.async.perform { asyncCompanion in
      var artworkRemoteInfos = [ArtworkRemoteInfo]()
      autoreleasepool {
        let artworks = asyncCompanion.library.getArtworksContainingBinaryData()
        artworkRemoteInfos = artworks.compactMap { $0.remoteInfo }
      }
      notifier.startOperation(name: "Artwork Update", totalCount: artworkRemoteInfos.count)
      for artworkRemoteInfo in artworkRemoteInfos {
        UpdateHelper().moveArtworkToFileManager(
          artworkRemoteInfo: artworkRemoteInfo,
          asyncCompanion: asyncCompanion
        )
        asyncCompanion.library.saveContext()
        notifier.tickOperation()
      }
    }
    os_log("Embedded Artwork Update", log: self.log, type: .info)
    try await storage.async.perform { asyncCompanion in
      var embeddedArtworkOwners = [AbstractPlayable]()
      autoreleasepool {
        let embeddedArtworks = asyncCompanion.library.getEmbeddedArtworksContainingBinaryData()
        embeddedArtworkOwners = embeddedArtworks.compactMap { $0.owner }
      }
      notifier.startOperation(
        name: "Embedded Artwork Update",
        totalCount: embeddedArtworkOwners.count
      )
      for embeddedArtworkOwner in embeddedArtworkOwners {
        UpdateHelper().moveEmbeddedArtworkToFileManager(
          embeddedArtworkOwner: embeddedArtworkOwner,
          asyncCompanion: asyncCompanion
        )
        asyncCompanion.library.saveContext()
        notifier.tickOperation()
      }
    }
    os_log("Songs/Podcast Episode Update", log: self.log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let cachedSongs = asyncCompanion.library.getCachedSongsThatHaveFileDataInCoreData()
      let cachedEpisodes = asyncCompanion.library
        .getCachedPodcastEpisodesThatHaveFileDataInCoreData()
      notifier.startOperation(
        name: "Songs/Episodes Update",
        totalCount: cachedSongs.count + cachedEpisodes.count
      )
      for cachedSong in cachedSongs {
        UpdateHelper().movePlayableToFileManager(
          playable: cachedSong,
          asyncCompanion: asyncCompanion
        )
        asyncCompanion.library.saveContext()
        notifier.tickOperation()
      }
      for cachedEpisode in cachedEpisodes {
        UpdateHelper().movePlayableToFileManager(
          playable: cachedEpisode,
          asyncCompanion: asyncCompanion
        )
        asyncCompanion.library.saveContext()
        notifier.tickOperation()
      }
      asyncCompanion.library.deleteBinaryPlayableFileSavedInCoreData()
      asyncCompanion.library.saveContext()
    }
    os_log(
      "Perform blocking library update (DONE): Extract  Binary Data",
      log: self.log,
      type: .info
    )
  }

  @MainActor
  private func sortPlaylistItems(notifier: LibraryUpdaterCallbacks) async throws {
    os_log("Playlist items delete orphans", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let orphanPlaylistItems = asyncCompanion.library.getPlaylistItemOrphans()
      for orphanPlaylistItem in orphanPlaylistItems {
        asyncCompanion.library.deletePlaylistItem(item: orphanPlaylistItem)
      }
    }
    os_log("Playlist items sort", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let playlists = asyncCompanion.library.getPlaylists(
        isFaultsOptimized: true,
        areSystemPlaylistsIncluded: true
      )
      notifier.startOperation(name: "Playlist Update", totalCount: playlists.count)
      for playlist in playlists {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        let playables = asyncCompanion.library.getPlaylistItems(playlist: playlist)
          .compactMap { AbstractPlayable(managedObject: $0.playable) }
        playlist.removeAllItems()
        for playable in playables {
          playlist.createAndAppendPlaylistItem(for: playable)
        }
        playlist.reassignOrder()
        playlist.updateArtworkItems()
        notifier.tickOperation()
      }
    }
  }

  @MainActor
  private func denormalizeCount(notifier: LibraryUpdaterCallbacks) async throws {
    os_log("Music Folder Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let musicFolders = asyncCompanion.library.getMusicFolders(isFaultsOptimized: true)
      notifier.startOperation(name: "Music Folder Update", totalCount: musicFolders.count)
      for musicFolder in musicFolders {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        musicFolder.managedObject.songCount = Int16(musicFolder.songs.count)
        musicFolder.managedObject.directoryCount = Int16(musicFolder.directories.count)
        notifier.tickOperation()
      }
    }
    os_log("Directory Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let directories = asyncCompanion.library.getDirectories(isFaultsOptimized: true)
      notifier.startOperation(name: "Directory Update", totalCount: directories.count)
      for directory in directories {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        directory.managedObject.songCount = Int16(directory.songs.count)
        directory.managedObject.subdirectoryCount = Int16(directory.subdirectories.count)
        notifier.tickOperation()
      }
    }
    os_log("Genre Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let genres = asyncCompanion.library.getGenres(isFaultsOptimized: true)
      notifier.startOperation(name: "Genre Update", totalCount: genres.count)
      for genre in genres {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        genre.managedObject.songCount = Int16(genre.songs.count)
        genre.managedObject.albumCount = Int16(genre.albums.count)
        genre.managedObject.artistCount = Int16(genre.artists.count)
        notifier.tickOperation()
      }
    }
    os_log("Artist Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let artists = asyncCompanion.library.getArtists(isFaultsOptimized: true)
      notifier.startOperation(name: "Artist Update", totalCount: artists.count)
      for artist in artists {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        artist.managedObject.remoteAlbumCount = artist.managedObject.albumCount
        artist.managedObject.albumCount = Int16(artist.albums.count)
        artist.managedObject.songCount = Int16(artist.songs.count)
        notifier.tickOperation()
      }
    }
    os_log("Album Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let albums = asyncCompanion.library.getAlbums(isFaultsOptimized: true)
      notifier.startOperation(name: "Album Update", totalCount: albums.count)
      for album in albums {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        album.managedObject.remoteSongCount = album.managedObject.songCount
        album.managedObject.songCount = Int16(album.songs.count)
        notifier.tickOperation()
      }
    }
    os_log("Podcast Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let podcasts = asyncCompanion.library.getPodcasts(isFaultsOptimized: true)
      notifier.startOperation(name: "Podcast Update", totalCount: podcasts.count)
      for podcast in podcasts {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        podcast.managedObject.episodeCount = Int16(podcast.episodes.count)
        notifier.tickOperation()
      }
    }
  }
}
