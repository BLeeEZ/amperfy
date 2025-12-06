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

import CoreData
import Foundation
import os.log

// MARK: - LibraryUpdaterCallbacks

public protocol LibraryUpdaterCallbacks: Sendable {
  func startOperation(name: String, totalCount: Int)
  func tickOperation()
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
    if storage.librarySyncVersion < .v20 {
      storage
        .librarySyncVersion =
        .v20 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking preference update: Streaming Transcoding Format Wifi/Cellular",
        log: log,
        type: .info
      )
      storage.settings.streamingFormatWifiPreference = storage.settings.streamingFormatPreference
      storage.settings.streamingFormatCellularPreference = storage.settings
        .streamingFormatPreference
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
    if storage.librarySyncVersion < .v18 {
      // add radios to libraryDisplaySettings to display it for old users
      var libraryDisplaySettingsInUse = storage.settings.libraryDisplaySettings.inUse
      if !libraryDisplaySettingsInUse.contains(where: { $0 == .radios }) {
        libraryDisplaySettingsInUse.append(.radios)
        storage.settings
          .libraryDisplaySettings = LibraryDisplaySettings(inUse: libraryDisplaySettingsInUse)
      }

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
    if storage.librarySyncVersion < .v21 {
      storage
        .librarySyncVersion =
        .v21 // if App crashes don't do this step again -> This step is only for convenience
      os_log(
        "Perform blocking library update (START): Account support",
        log: self.log,
        type: .info
      )
      try await applyAccountSupport(notifier: notifier)
      os_log(
        "Perform blocking library update (DONE): Account support",
        log: self.log,
        type: .info
      )
    }
  }

  @MainActor
  private func updateAlphabeticSectionInitial() {
    os_log("Library update: Genres", log: log, type: .info)
    let genres = storage.main.library.getAllGenres()
    genres.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Artists", log: log, type: .info)
    let artists = storage.main.library.getAllArtists()
    artists.forEach { $0.updateAlphabeticSectionInitial(section: $0.name) }
    os_log("Library update: Albums", log: log, type: .info)
    let albums = storage.main.library.getAllAlbums()
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
        musicFolder.managedObject.songCount = Int16(clamping: musicFolder.songs.count)
        musicFolder.managedObject.directoryCount = Int16(clamping: musicFolder.directories.count)
        notifier.tickOperation()
      }
    }
    os_log("Directory Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let directories = asyncCompanion.library.getDirectories(isFaultsOptimized: true)
      notifier.startOperation(name: "Directory Update", totalCount: directories.count)
      for directory in directories {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        directory.managedObject.songCount = Int16(clamping: directory.songs.count)
        directory.managedObject.subdirectoryCount = Int16(clamping: directory.subdirectories.count)
        notifier.tickOperation()
      }
    }
    os_log("Genre Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let genres = asyncCompanion.library.getAllGenres()
      notifier.startOperation(name: "Genre Update", totalCount: genres.count)
      for genre in genres {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        genre.managedObject.songCount = Int16(clamping: genre.songs.count)
        genre.managedObject.albumCount = Int16(clamping: genre.albums.count)
        genre.managedObject.artistCount = Int16(clamping: genre.artists.count)
        notifier.tickOperation()
      }
    }
    os_log("Artist Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let artists = asyncCompanion.library.getAllArtists()
      notifier.startOperation(name: "Artist Update", totalCount: artists.count)
      for artist in artists {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        artist.managedObject.remoteAlbumCount = artist.managedObject.albumCount
        artist.managedObject.albumCount = Int16(clamping: artist.albums.count)
        artist.managedObject.songCount = Int16(clamping: artist.songs.count)
        notifier.tickOperation()
      }
    }
    os_log("Album Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let albums = asyncCompanion.library.getAllAlbums()
      notifier.startOperation(name: "Album Update", totalCount: albums.count)
      for album in albums {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        album.managedObject.remoteSongCount = album.managedObject.songCount
        album.managedObject.songCount = Int16(clamping: album.songs.count)
        notifier.tickOperation()
      }
    }
    os_log("Podcast Denormalize", log: log, type: .info)
    try await storage.async.perform { asyncCompanion in
      let podcasts = asyncCompanion.library.getPodcasts(isFaultsOptimized: true)
      notifier.startOperation(name: "Podcast Update", totalCount: podcasts.count)
      for podcast in podcasts {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        podcast.managedObject.episodeCount = Int16(clamping: podcast.episodes.count)
        notifier.tickOperation()
      }
    }
  }

  @MainActor
  func applyAccountSupport(notifier: LibraryUpdaterCallbacks) async throws {
    os_log("Create account (url + user) entry in CoreData", log: log, type: .info)
    guard let credentials = storage.loginCredentials else { return }
    var accountObjectIdTemp: NSManagedObjectID!
    let accountInfo = Account.createInfo(credentials: credentials)
    storage.main.perform { asyncCompanion in
      let account = asyncCompanion.library.getAccount(info: accountInfo)
      accountObjectIdTemp = account.managedObject.objectID
    }
    let accountObjectId: NSManagedObjectID = accountObjectIdTemp

    os_log(
      "Create new account/user directory and move all files/dirs inside the account dir",
      log: log,
      type: .info
    )
    try? fileManager.move(
      from: fileManager.getAbsoluteAmperfyPath(relFilePath: URL(string: "artworks")!),
      to: fileManager.getOrCreateAbsoluteArtworksDirectory(for: accountInfo)
    )
    try? fileManager.move(
      from: fileManager.getAbsoluteAmperfyPath(relFilePath: URL(string: "embedded-artworks")!),
      to: fileManager.getOrCreateAbsoluteEmbeddedArtworksDirectory(for: accountInfo)
    )
    try? fileManager.move(
      from: fileManager.getAbsoluteAmperfyPath(relFilePath: URL(string: "episodes")!),
      to: fileManager.getOrCreateAbsolutePodcastEpisodesDirectory(for: accountInfo)
    )
    try? fileManager.move(
      from: fileManager.getAbsoluteAmperfyPath(relFilePath: URL(string: "lyrics")!),
      to: fileManager.getOrCreateAbsoluteLyricsDirectory(for: accountInfo)
    )
    try? fileManager.move(
      from: fileManager.getAbsoluteAmperfyPath(relFilePath: URL(string: "songs")!),
      to: fileManager.getOrCreateAbsoluteSongsDirectory(for: accountInfo)
    )

    os_log(
      "Iterate over all library elements with rel file paths and update rel path",
      log: log,
      type: .info
    )
    /*
     - artworks
       - album
       - artist
       - podcast
     - embedded-artworks
       - episodes
       - songs
     - episodes
     - lyrics
       - songs
     - songs
     */
    let newServerRelFilePath = fileManager.getRelPath(for: accountInfo)!

    try await storage.async.perform { asyncCompanion in
      let artworks = asyncCompanion.library.getArtworks()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Artwork Update", totalCount: artworks.count)
      for artwork in artworks {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        if let relFilePath = artwork.relFilePath {
          artwork.relFilePath = newServerRelFilePath.appendingPathComponent(relFilePath.path)
        }
        artwork.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let embeddedArtworks = asyncCompanion.library.getEmbeddedArtworks()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Embedded Artwork Update", totalCount: embeddedArtworks.count)
      for artwork in embeddedArtworks {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        if let relFilePath = artwork.relFilePath {
          artwork.relFilePath = newServerRelFilePath.appendingPathComponent(relFilePath.path)
        }
        artwork.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let episodes = asyncCompanion.library.getPodcastEpisodes()
      notifier.startOperation(name: "Podcast Episodes Update", totalCount: episodes.count)
      for episode in episodes {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        if let relFilePath = episode.relFilePath {
          episode.relFilePath = newServerRelFilePath.appendingPathComponent(relFilePath.path)
        }
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let songs = asyncCompanion.library.getSongs()
      notifier.startOperation(name: "Songs Update", totalCount: songs.count)
      for song in songs {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        if let relFilePath = song.relFilePath {
          song.relFilePath = newServerRelFilePath.appendingPathComponent(relFilePath.path)
        }
        if let lyricsRelFilePath = song.lyricsRelFilePath {
          song.lyricsRelFilePath = newServerRelFilePath
            .appendingPathComponent(lyricsRelFilePath.path)
        }
        notifier.tickOperation()
      }
    }

    os_log("Iterate over all library elements to assign account", log: log, type: .info)
    /*
     x AbstractLibraryEntity
     x Artworks -> done in rel path
     x Downloads
     x EmbeddedArtworks -> done in rel path
     x MusicFolders
     x PlayerData
     x PlaylistItems
     x Playlists
     x ScrobbleEntries
     x SearchHistories
     */
    try await storage.async.perform { asyncCompanion in
      let entities = asyncCompanion.library.getAbstractLibraryEntities()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "General Update", totalCount: entities.count)
      for entity in entities {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        entity.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let downloads = asyncCompanion.library.getAllDownloads()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Download Update", totalCount: downloads.count)
      for download in downloads {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        download.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let musicFolders = asyncCompanion.library.getMusicFolders()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Music Folders Update", totalCount: musicFolders.count)
      for musicFolder in musicFolders {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        musicFolder.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let playerDatas = asyncCompanion.library.getAllPlayerData()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Player Update", totalCount: playerDatas.count)
      for playerData in playerDatas {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        playerData.account = accountAsync.managedObject
        playerData.contextPlaylist?.account = accountAsync.managedObject
        playerData.shuffledContextPlaylist?.account = accountAsync.managedObject
        playerData.userQueuePlaylist?.account = accountAsync.managedObject
        playerData.podcastPlaylist?.account = accountAsync.managedObject
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let playlists = asyncCompanion.library.getPlaylists()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Playlists Update", totalCount: playlists.count)
      for playlist in playlists {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        playlist.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let playlistItems = asyncCompanion.library.getPlaylistItems()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Playlist Items Update", totalCount: playlistItems.count)
      for playlistItem in playlistItems {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        playlistItem.account = accountAsync.managedObject
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let scrobbleEntries = asyncCompanion.library.getScrobbleEntries()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Scrobbles Update", totalCount: scrobbleEntries.count)
      for scrobbleEntry in scrobbleEntries {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        scrobbleEntry.account = accountAsync
        notifier.tickOperation()
      }
    }
    try await storage.async.perform { asyncCompanion in
      let searchHistory = asyncCompanion.library.getAllSearchHistory()
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: accountObjectId) as! AccountMO
      )
      notifier.startOperation(name: "Search History Update", totalCount: searchHistory.count)
      for searchHistoryItem in searchHistory {
        usleep(Self.sleepTimeInMicroSecToReduceCpuLoad)
        searchHistoryItem.account = accountAsync
        notifier.tickOperation()
      }
    }

    /*
     Elements to adjust for creation
        x‚ AbstractLibraryEntity
          x AbstractPlayable
            x Song
            x PodcastEpisode
            x Radio
          x Album
          x Artist
          x Directory
          x Genre
          x Podcast
        x artworks
        x downloads
        x embeddedArtworks
        x musicFolders
        x player
        x playlistItems
        x playlists
        x scrobbleEntries
        x searchHistories
        */
  }
}
