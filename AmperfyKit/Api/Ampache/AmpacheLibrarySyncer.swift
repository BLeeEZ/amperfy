//
//  AmpacheLibrarySyncer.swift
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

class AmpacheLibrarySyncer: CommonLibrarySyncer, LibrarySyncer {
  private let ampacheXmlServerApi: AmpacheXmlServerApi

  init(
    ampacheXmlServerApi: AmpacheXmlServerApi,
    account: Account,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    storage: PersistentStorage,
    eventLogger: EventLogger
  ) {
    self.ampacheXmlServerApi = ampacheXmlServerApi
    super.init(
      account: account,
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      storage: storage,
      eventLogger: eventLogger
    )
  }

  @MainActor
  func syncInitial(statusNotifyier: SyncCallbacks?) async throws {
    try await super.createCachedItemRepresentationsInCoreData(statusNotifyier: statusNotifyier)
    let auth = try await ampacheXmlServerApi.requesetLibraryMetaData()
    statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: auth.genreCount)
    let genreResponse = try await ampacheXmlServerApi.requestGenres()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: genreResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = GenreParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: statusNotifyier
      )
      try self.parse(
        response: genreResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
    }

    statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: auth.artistCount)
    let pollCountArtist = max(
      1,
      Int(ceil(Double(auth.artistCount) / Double(AmpacheXmlServerApi.maxItemCountToPollAtOnce)))
    )
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for index in Array(0 ... pollCountArtist) {
        taskGroup.addTask { @MainActor @Sendable in
          let artistsResponse = try await self.ampacheXmlServerApi
            .requestArtists(startIndex: index * AmpacheXmlServerApi.maxItemCountToPollAtOnce)
          try await self.storage.async.perform { asyncCompanion in
            let accountAsync = Account(
              managedObject: asyncCompanion.context
                .object(with: self.accountObjectId) as! AccountMO
            )
            let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
            try self.parse(
              response: artistsResponse,
              delegate: idParserDelegate,
              isThrowingErrorsAllowed: false
            )
            let prefetch = asyncCompanion.library
              .getElements(account: accountAsync, prefetchIDs: idParserDelegate.prefetchIDs)

            let parserDelegate = ArtistParserDelegate(
              performanceMonitor: self.performanceMonitor, prefetch: prefetch,
              account: accountAsync,
              library: asyncCompanion.library,
              parseNotifier: statusNotifyier
            )
            try self.parse(
              response: artistsResponse,
              delegate: parserDelegate,
              isThrowingErrorsAllowed: false
            )
          }
        }
      }
      try await taskGroup.waitForAll()
    }

    statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: auth.albumCount)
    let pollCountAlbum = max(
      1,
      Int(ceil(Double(auth.albumCount) / Double(AmpacheXmlServerApi.maxItemCountToPollAtOnce)))
    )
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for index in Array(0 ... pollCountAlbum) {
        taskGroup.addTask { @MainActor @Sendable in
          let albumsResponse = try await self.ampacheXmlServerApi
            .requestAlbums(startIndex: index * AmpacheXmlServerApi.maxItemCountToPollAtOnce)
          try await self.storage.async.perform { asyncCompanion in
            let accountAsync = Account(
              managedObject: asyncCompanion.context
                .object(with: self.accountObjectId) as! AccountMO
            )
            let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
            try self.parse(
              response: albumsResponse,
              delegate: idParserDelegate,
              isThrowingErrorsAllowed: false
            )
            let prefetch = asyncCompanion.library
              .getElements(account: accountAsync, prefetchIDs: idParserDelegate.prefetchIDs)

            let parserDelegate = AlbumParserDelegate(
              performanceMonitor: self.performanceMonitor, prefetch: prefetch,
              account: accountAsync,
              library: asyncCompanion.library,
              parseNotifier: statusNotifyier
            )
            try self.parse(
              response: albumsResponse,
              delegate: parserDelegate,
              isThrowingErrorsAllowed: false
            )
          }
        }
      }
      try await taskGroup.waitForAll()
    }

    statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: auth.playlistCount)
    let playlistsResponse = try await ampacheXmlServerApi.requestPlaylists()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let parserDelegate = PlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: statusNotifyier
      )
      try self.parse(
        response: playlistsResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
    }

    let isSupported = try await ampacheXmlServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: auth.podcastCount)
    let podcastsResponse = try await ampacheXmlServerApi.requestPodcasts()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: podcastsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = PodcastParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: statusNotifyier
      )
      try self.parse(
        response: podcastsResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
      parserDelegate.performPostParseOperations()
    }
  }

  @MainActor
  func sync(genre: Genre) async throws {
    guard isSyncAllowed else { return }
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for album in genre.albums {
        taskGroup.addTask { @MainActor @Sendable in
          try await self.sync(album: album)
        }
      }
      try await taskGroup.waitForAll()
    }
  }

  @MainActor
  func sync(artist: Artist) async throws {
    guard isSyncAllowed else { return }
    let artistResponse = try await ampacheXmlServerApi.requestArtistInfo(id: artist.id)
    let artistObjectId = artist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      do {
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: self.accountObjectId) as! AccountMO
        )
        let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(
          response: artistResponse,
          delegate: idParserDelegate,
          isThrowingErrorsAllowed: false
        )
        let prefetch = asyncCompanion.library.getElements(
          account: accountAsync,
          prefetchIDs: idParserDelegate.prefetchIDs
        )

        let parserDelegate = ArtistParserDelegate(
          performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
          library: asyncCompanion.library
        )

        try self.parse(
          response: artistResponse,
          delegate: parserDelegate,
          throwForNotFoundErrors: true
        )
      } catch {
        if let responseError = error as? ResponseError,
           let ampacheError = responseError.asAmpacheError, !ampacheError.isRemoteAvailable {
          let artistAsync = Artist(
            managedObject: asyncCompanion.context
              .object(with: artistObjectId) as! ArtistMO
          )
          let reportError = ResponseError(
            type: .resource,
            statusCode: responseError.statusCode,
            message: "Artist \"\(artistAsync.name)\" is no longer available on the server.",
            cleansedURL: artistResponse.url?.asCleansedURL(cleanser: self.ampacheXmlServerApi),
            data: artistResponse.data
          )
          artistAsync.remoteStatus = .deleted
          throw reportError
        } else {
          throw error
        }
      }
    }

    guard artist.remoteStatus == .available else { return }
    let artistAlbumsResponse = try await ampacheXmlServerApi.requestArtistAlbums(id: artist.id)

    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let artistAsync = Artist(
        managedObject: asyncCompanion.context
          .object(with: artistObjectId) as! ArtistMO
      )
      let oldAlbums = Set(artistAsync.albums)

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: artistAlbumsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = AlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: artistAlbumsResponse, delegate: parserDelegate)
      let removedAlbums = oldAlbums.subtracting(parserDelegate.albumsParsedSet)
      for album in removedAlbums {
        os_log("Album <%s> is remote deleted", log: self.log, type: .info, album.name)
        album.remoteStatus = .deleted
        album.songs.forEach {
          os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
          $0.remoteStatus = .deleted
        }
      }
    }

    let artistSongsResponse = try await ampacheXmlServerApi.requestArtistSongs(id: artist.id)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let artistAsync = Artist(
        managedObject: asyncCompanion.context
          .object(with: artistObjectId) as! ArtistMO
      )
      let oldSongs = Set(artistAsync.songs)

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: artistSongsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: artistSongsResponse, delegate: parserDelegate)
      let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
      removedSongs.lazy.compactMap { $0.asSong }.forEach {
        os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
        $0.remoteStatus = .deleted
      }
    }
  }

  @MainActor
  func sync(album: Album) async throws {
    guard isSyncAllowed else { return }
    let albumResponse = try await ampacheXmlServerApi.requestAlbumInfo(id: album.id)
    let albumObjectId = album.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      do {
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: self.accountObjectId) as! AccountMO
        )
        let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(
          response: albumResponse,
          delegate: idParserDelegate,
          isThrowingErrorsAllowed: false
        )
        let prefetch = asyncCompanion.library.getElements(
          account: accountAsync,
          prefetchIDs: idParserDelegate.prefetchIDs
        )

        let parserDelegate = AlbumParserDelegate(
          performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
          library: asyncCompanion.library
        )
        try self.parse(
          response: albumResponse,
          delegate: parserDelegate,
          throwForNotFoundErrors: true
        )
      } catch {
        if let responseError = error as? ResponseError,
           let ampacheError = responseError.asAmpacheError, !ampacheError.isRemoteAvailable {
          let albumAsync = Album(
            managedObject: asyncCompanion.context
              .object(with: albumObjectId) as! AlbumMO
          )
          let reportError = ResponseError(
            type: .resource,
            statusCode: responseError.statusCode,
            message: "Album \"\(albumAsync.name)\" is no longer available on the server.",
            cleansedURL: albumResponse.url?.asCleansedURL(cleanser: self.ampacheXmlServerApi),
            data: albumResponse.data
          )
          albumAsync.markAsRemoteDeleted()
          throw reportError
        } else {
          throw error
        }
      }
    }

    guard album.remoteStatus == .available else { return }
    let albumSongsResponse = try await ampacheXmlServerApi.requestAlbumSongs(id: album.id)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let albumAsync = Album(
        managedObject: asyncCompanion.context
          .object(with: albumObjectId) as! AlbumMO
      )
      let oldSongs = Set(albumAsync.songs)

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: albumSongsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: albumSongsResponse, delegate: parserDelegate)
      let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
      removedSongs.lazy.compactMap { $0.asSong }.forEach {
        os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
        $0.remoteStatus = .deleted
        albumAsync.managedObject.removeFromSongs($0.managedObject)
      }
      albumAsync.isSongsMetaDataSynced = true
      albumAsync.isCached = parserDelegate.isCollectionCached
    }
  }

  @MainActor
  func sync(song: Song) async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestSongInfo(id: song.id)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func sync(podcast: Podcast) async throws {
    guard isSyncAllowed else { return }
    let isSupported = try await ampacheXmlServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    let podcastObjectId = podcast.managedObject.objectID
    let response = try await ampacheXmlServerApi.requestPodcastEpisodes(id: podcast.id)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let podcastAsync = Podcast(
        managedObject: asyncCompanion.context
          .object(with: podcastObjectId) as! PodcastMO
      )
      let oldEpisodes = Set(podcastAsync.episodes)

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = PodcastEpisodeParserDelegate(
        performanceMonitor: self.performanceMonitor,
        podcast: podcastAsync, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      parserDelegate.performPostParseOperations()

      let deletedEpisodes = oldEpisodes.subtracting(parserDelegate.parsedEpisodes)
      deletedEpisodes.forEach {
        os_log(
          "Podcast Episode <%s> is remote deleted",
          log: self.log,
          type: .info,
          $0.displayString
        )
        $0.podcastStatus = .deleted
      }
      podcastAsync.isCached = parserDelegate.isCollectionCached
    }
  }

  @MainActor
  func syncNewestPodcastEpisodes() async throws {
    guard isSyncAllowed else { return }
    os_log("Sync newest podcast episodes", log: log, type: .info)
    let isSupported = try await ampacheXmlServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    try await syncDownPodcastsWithoutEpisodes()

    let podcasts = storage.main.library.getPodcasts(for: account)
      .filter { $0.remoteStatus == .available }
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      podcasts.forEach { podcast in
        let podcastObjectId = podcast.managedObject.objectID
        taskGroup.addTask { @MainActor @Sendable in
          let response = try await self.ampacheXmlServerApi.requestPodcastEpisodes(
            id: podcast.id,
            limit: 5
          )
          try await self.storage.async.perform { asyncCompanion in
            let accountAsync = Account(
              managedObject: asyncCompanion.context
                .object(with: self.accountObjectId) as! AccountMO
            )
            let podcastAsync = Podcast(
              managedObject: asyncCompanion.context
                .object(with: podcastObjectId) as! PodcastMO
            )

            let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
            try self.parse(
              response: response,
              delegate: idParserDelegate,
              isThrowingErrorsAllowed: false
            )
            let prefetch = asyncCompanion.library
              .getElements(account: accountAsync, prefetchIDs: idParserDelegate.prefetchIDs)

            let parserDelegate = PodcastEpisodeParserDelegate(
              performanceMonitor: self.performanceMonitor,
              podcast: podcastAsync, prefetch: prefetch, account: accountAsync,
              library: asyncCompanion.library
            )
            try self.parse(response: response, delegate: parserDelegate)
            parserDelegate.performPostParseOperations()
          }
        }
      }
      try await taskGroup.waitForAll()
    }
  }

  @MainActor
  func syncMusicFolders() async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestCatalogs()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = CatalogParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func syncIndexes(musicFolder: MusicFolder) async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestArtistWithinCatalog(id: musicFolder.id)
    let musicFolderObjectId = musicFolder.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = ArtistParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)

      let musicFolderAsync = MusicFolder(
        managedObject: asyncCompanion.context
          .object(with: musicFolderObjectId) as! MusicFolderMO
      )
      let directoriesBeforeFetch = Set(musicFolderAsync.directories)
      var directoriesAfterFetch: Set<Directory> = Set()

      let artistDirectoryIds = parserDelegate.artistsParsed.compactMap {
        "artist-\($0.id)"
      }
      let artistDirectoryIdsSet = Set(artistDirectoryIds)
      let directoriesForArtists = asyncCompanion.library.getDirectories(
        account: accountAsync,
        ids: artistDirectoryIdsSet
      )

      for artist in parserDelegate.artistsParsed {
        let artistDirId = "artist-\(artist.id)"

        var curDir: Directory!
        if let foundDir = directoriesForArtists[artistDirId] {
          curDir = foundDir
        } else {
          curDir = asyncCompanion.library.createDirectory(account: accountAsync)
          curDir.id = artistDirId
        }
        curDir.name = artist.name
        musicFolderAsync.managedObject.addToDirectories(curDir.managedObject)
        directoriesAfterFetch.insert(curDir)
      }

      let removedDirectories = directoriesBeforeFetch.subtracting(directoriesAfterFetch)
      removedDirectories.forEach { asyncCompanion.library.deleteDirectory(directory: $0) }
    }
  }

  @MainActor
  func sync(directory: Directory) async throws {
    guard isSyncAllowed else { return }
    if directory.id.starts(with: "album-") {
      let albumId = String(directory.id.dropFirst("album-".count))
      try await sync(directory: directory, thatIsAlbumId: albumId)
    } else if directory.id.starts(with: "artist-") {
      let artistId = String(directory.id.dropFirst("artist-".count))
      try await sync(directory: directory, thatIsArtistId: artistId)
    } else {
      // do nothing
    }
  }

  @MainActor
  private func sync(directory: Directory, thatIsAlbumId albumId: String) async throws {
    guard let album = storage.main.library.getAlbum(
      for: account,
      id: albumId,
      isDetailFaultResolution: true
    )
    else { return }
    let songsObjectIdsBeforeFetch = Set(directory.songs).compactMap { $0.managedObject.objectID }
    let directoryObjectId = directory.managedObject.objectID
    let albumObjectId = album.managedObject.objectID

    try await sync(album: album)
    try await storage.async.perform { asyncCompanion in
      let directoryAsync = Directory(
        managedObject: asyncCompanion.context
          .object(with: directoryObjectId) as! DirectoryMO
      )
      let albumAsync = Album(
        managedObject: asyncCompanion.context
          .object(with: albumObjectId) as! AlbumMO
      )
      let songsBeforeFetchAsync = Set(songsObjectIdsBeforeFetch.compactMap {
        Song(managedObject: asyncCompanion.context.object(with: $0) as! SongMO)
      })

      directoryAsync.songs
        .forEach { directoryAsync.managedObject.removeFromSongs($0.managedObject) }
      let songsToRemove = songsBeforeFetchAsync
        .subtracting(Set(albumAsync.songs.compactMap { $0.asSong }))
      songsToRemove.lazy.compactMap { $0.asSong }.forEach {
        directoryAsync.managedObject.removeFromSongs($0.managedObject)
      }
      albumAsync.songs.compactMap { $0.asSong }.forEach {
        directoryAsync.managedObject.addToSongs($0.managedObject)
      }
      directoryAsync.isCached = albumAsync.isCached
    }
  }

  @MainActor
  private func sync(directory: Directory, thatIsArtistId artistId: String) async throws {
    guard let artist = storage.main.library.getArtist(for: account, id: artistId) else { return }
    let directoriesObjectIdsBeforeFetch = Set(directory.subdirectories)
      .compactMap { $0.managedObject.objectID }
    let directoryObjectId = directory.managedObject.objectID
    let artistObjectId = artist.managedObject.objectID

    try await sync(artist: artist)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let directoryAsync = Directory(
        managedObject: asyncCompanion.context
          .object(with: directoryObjectId) as! DirectoryMO
      )
      let artistAsync = Artist(
        managedObject: asyncCompanion.context
          .object(with: artistObjectId) as! ArtistMO
      )
      let directoriesBeforeFetchAsync = Set(directoriesObjectIdsBeforeFetch.compactMap {
        Directory(managedObject: asyncCompanion.context.object(with: $0) as! DirectoryMO)
      })

      var directoriesAfterFetch: Set<Directory> = Set()
      let artistAlbums = asyncCompanion.library.getAlbums(
        for: accountAsync,
        whichContainsSongsWithArtist: artistAsync
      )

      let albumDirectoryIds = artistAlbums.compactMap {
        "album-\($0.id)"
      }
      let albumDirectoryIdsSet = Set(albumDirectoryIds)
      let directoriesForAlbums = asyncCompanion.library.getDirectories(
        account: accountAsync,
        ids: albumDirectoryIdsSet
      )

      for album in artistAlbums {
        let albumDirId = "album-\(album.id)"
        var albumDir: Directory!
        if let foundDir = directoriesForAlbums[albumDirId] {
          albumDir = foundDir
        } else {
          albumDir = asyncCompanion.library.createDirectory(account: accountAsync)
          albumDir.id = albumDirId
        }
        albumDir.name = album.name
        albumDir.artwork = album.artwork
        directoryAsync.managedObject.addToSubdirectories(albumDir.managedObject)
        directoriesAfterFetch.insert(albumDir)
      }

      let directoriesToRemove = directoriesBeforeFetchAsync.subtracting(directoriesAfterFetch)
      directoriesToRemove.forEach {
        directoryAsync.managedObject.removeFromSubdirectories($0.managedObject)
      }
    }
  }

  @MainActor
  func syncNewestAlbums(offset: Int, count: Int) async throws {
    guard isSyncAllowed else { return }
    os_log("Sync newest albums: offset: %i count: %i", log: log, type: .info, offset, count)
    let response = try await ampacheXmlServerApi.requestNewestAlbums(offset: offset, count: count)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = AlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      let oldNewestAlbums = asyncCompanion.library.getNewestAlbums(
        for: accountAsync,
        offset: offset,
        count: count
      )
      oldNewestAlbums.forEach { $0.markAsNotNewAnymore() }
      parserDelegate.albumsParsedArray.enumerated().forEach { index, album in
        album.updateIsNewestInfo(index: index + 1 + offset)
      }
    }
  }

  @MainActor
  func syncRecentAlbums(offset: Int, count: Int) async throws {
    guard isSyncAllowed else { return }
    os_log("Sync recent albums: offset: %i count: %i", log: log, type: .info, offset, count)
    let response = try await ampacheXmlServerApi.requestRecentAlbums(offset: offset, count: count)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = AlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      let oldRecentAlbums = asyncCompanion.library.getRecentAlbums(
        for: accountAsync,
        offset: offset,
        count: count
      )
      oldRecentAlbums.forEach { $0.markAsNotRecentAnymore() }
      parserDelegate.albumsParsedArray.enumerated().forEach { index, album in
        album.updateIsRecentInfo(index: index + 1 + offset)
      }
    }
  }

  @MainActor
  func syncFavoriteLibraryElements() async throws {
    guard isSyncAllowed else { return }
    let artistsResponse = try await ampacheXmlServerApi.requestFavoriteArtists()
    try await storage.async.perform { asyncCompanion in
      os_log("Sync favorite artists", log: self.log, type: .info)
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldFavoriteArtists = Set(asyncCompanion.library.getFavoriteArtists(for: accountAsync))

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: artistsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = ArtistParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: artistsResponse, delegate: parserDelegate)

      let notFavoriteArtistsAnymore = oldFavoriteArtists.subtracting(parserDelegate.artistsParsed)
      notFavoriteArtistsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
    }

    let albumsResponse = try await ampacheXmlServerApi.requestFavoriteAlbums()
    try await storage.async.perform { asyncCompanion in
      os_log("Sync favorite albums", log: self.log, type: .info)
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldFavoriteAlbums = Set(asyncCompanion.library.getFavoriteAlbums(for: accountAsync))

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: albumsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = AlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: albumsResponse, delegate: parserDelegate)

      let notFavoriteAlbumsAnymore = oldFavoriteAlbums.subtracting(parserDelegate.albumsParsedSet)
      notFavoriteAlbumsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
    }

    let songsResponse = try await ampacheXmlServerApi.requestFavoriteSongs()
    try await storage.async.perform { asyncCompanion in
      os_log("Sync favorite songs", log: self.log, type: .info)
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldFavoriteSongs = Set(asyncCompanion.library.getFavoriteSongs(for: accountAsync))

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: songsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: songsResponse, delegate: parserDelegate)

      let notFavoriteSongsAnymore = oldFavoriteSongs.subtracting(parserDelegate.parsedSongs)
      notFavoriteSongsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
    }
  }

  @MainActor
  func syncRadios() async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestRadios()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldRadios = Set(asyncCompanion.library.getRadios(for: accountAsync))

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = RadioParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: nil
      )
      try self.parse(response: response, delegate: parserDelegate)

      let deletedRadios = oldRadios.subtracting(parserDelegate.parsedRadios)
      deletedRadios.forEach {
        os_log("Radio <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
        $0.remoteStatus = .deleted
      }
    }
  }

  @MainActor
  func requestRandomSongs(playlist: Playlist, count: Int) async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestRandomSongs(count: count)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: nil
      )
      try self.parse(response: response, delegate: parserDelegate)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )
      playlistAsync.append(playables: parserDelegate.parsedSongs)
    }
  }

  @MainActor
  func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
    try parseForError(response: response)
  }

  @MainActor
  func syncDownPlaylistsWithoutSongs() async throws {
    guard isSyncAllowed else { return }
    let response = try await ampacheXmlServerApi.requestPlaylists()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let parserDelegate = PlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: nil
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func syncDown(playlist: Playlist) async throws {
    guard isSyncAllowed else { return }
    os_log("Playlist \"%s\": Validate from server", log: log, type: .info, playlist.name)
    try await validatePlaylistId(playlist: playlist)
    os_log("Playlist \"%s\": Download songs from server", log: self.log, type: .info, playlist.name)
    let response = try await ampacheXmlServerApi.requestPlaylistSongs(id: playlist.id)

    os_log("Playlist \"%s\": Parse songs start", log: self.log, type: .info, playlist.name)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = PlaylistSongsParserDelegate(
        performanceMonitor: self.performanceMonitor,
        playlist: playlistAsync, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      playlistAsync.isCached = parserDelegate.isCollectionCached
      playlistAsync.remoteDuration = parserDelegate.collectionDuration
      os_log(
        "Playlist \"%s\": Parse songs (%i) done",
        log: self.log,
        type: .info,
        playlistAsync.name,
        parserDelegate.parsedCount
      )
    }
  }

  @MainActor
  func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws {
    guard isSyncAllowed, !songs.isEmpty else { return }
    os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
    try await validatePlaylistId(playlist: playlist)
    for song in songs {
      let response = try await ampacheXmlServerApi.requestPlaylistAddSong(
        playlistId: playlist.id,
        songId: song.id
      )
      try parseForError(response: response)
    }
  }

  @MainActor
  func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) async throws {
    guard isSyncAllowed else { return }
    os_log(
      "Upload SongDelete on playlist \"%s\" at index: %i",
      log: log,
      type: .info,
      playlist.name,
      index
    )
    try await validatePlaylistId(playlist: playlist)
    let response = try await ampacheXmlServerApi.requestPlaylistDeleteItem(
      id: playlist.id,
      index: index
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistToUpdateName playlist: Playlist) async throws {
    guard isSyncAllowed else { return }
    os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
    let response = try await ampacheXmlServerApi.requestPlaylistEditOnlyName(
      id: playlist.id,
      name: playlist.name
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws {
    guard isSyncAllowed, playlist.songCount > 0 else { return }
    os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
    let songIds = playlist.playables.compactMap { $0.id }
    guard !songIds.isEmpty else { return }
    let response = try await ampacheXmlServerApi.requestPlaylistEdit(
      id: playlist.id,
      songsIds: songIds
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistIdToDelete id: String) async throws {
    guard isSyncAllowed else { return }
    os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
    let response = try await ampacheXmlServerApi.requestPlaylistDelete(id: id)
    try parseForError(response: response)
  }

  @MainActor
  private func validatePlaylistId(playlist: Playlist) async throws {
    let playlistResponse = try await ampacheXmlServerApi.requestPlaylist(id: playlist.id)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )
      let parserDelegate = PlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: nil,
        playlistToValidate: playlistAsync
      )
      try self.parse(response: playlistResponse, delegate: parserDelegate)
    }
    guard playlist.id == "" else { return }
    os_log("Create playlist on server", log: self.log, type: .info)

    let playlistCreateResponse = try await ampacheXmlServerApi
      .requestPlaylistCreate(name: playlist.name)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )
      let parserDelegate = PlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: nil,
        playlistToValidate: playlistAsync
      )
      try self.parse(response: playlistCreateResponse, delegate: parserDelegate)
    }
    if playlist.id == "" {
      os_log("Playlist id was not assigned after creation", log: self.log, type: .info)
      throw BackendError
        .incorrectServerBehavior(message: "Playlist id was not assigned after creation")
    }
  }

  @MainActor
  func syncDownPodcastsWithoutEpisodes() async throws {
    guard isSyncAllowed else { return }
    let isSupported = try await ampacheXmlServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    let response = try await ampacheXmlServerApi.requestPodcasts()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldPodcasts = Set(asyncCompanion.library.getRemoteAvailablePodcasts(for: accountAsync))

      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = PodcastParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      parserDelegate.performPostParseOperations()

      let deletedPodcasts = oldPodcasts.subtracting(parserDelegate.parsedPodcasts)
      deletedPodcasts.forEach {
        os_log("Podcast <%s> is remote deleted", log: self.log, type: .info, $0.title)
        $0.remoteStatus = .deleted
      }
    }
  }

  /// Ampache has no equivalend to Subsonic's NowPlaying
  @MainActor
  func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws {
    switch songPosition {
    case .start:
      break // Do nothing
    case .end:
      try await scrobble(song: song, date: nil)
    }
  }

  @MainActor
  func scrobble(song: Song, date: Date?) async throws {
    guard isSyncAllowed else { return }
    if let date = date {
      os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
    } else {
      os_log("Scrobble now: %s", log: log, type: .info, song.displayString)
    }
    let response = try await ampacheXmlServerApi.requestRecordPlay(songId: song.id, date: date)
    try parseForError(response: response)
  }

  @MainActor
  func setRating(song: Song, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
    let response = try await ampacheXmlServerApi.requestRate(songId: song.id, rating: rating)
    try parseForError(response: response)
  }

  @MainActor
  func setRating(album: Album, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
    let response = try await ampacheXmlServerApi.requestRate(albumId: album.id, rating: rating)
    try parseForError(response: response)
  }

  @MainActor
  func setRating(artist: Artist, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
    let response = try await ampacheXmlServerApi.requestRate(artistId: artist.id, rating: rating)
    try parseForError(response: response)
  }

  @MainActor
  func setFavorite(song: Song, isFavorite: Bool) async throws {
    guard isSyncAllowed else { return }
    os_log(
      "Set Favorite %s: %s",
      log: log,
      type: .info,
      isFavorite ? "TRUE" : "FALSE",
      song.displayString
    )
    let response = try await ampacheXmlServerApi.requestSetFavorite(
      songId: song.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func setFavorite(album: Album, isFavorite: Bool) async throws {
    guard isSyncAllowed else { return }
    os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
    let response = try await ampacheXmlServerApi.requestSetFavorite(
      albumId: album.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func setFavorite(artist: Artist, isFavorite: Bool) async throws {
    guard isSyncAllowed else { return }
    os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
    let response = try await ampacheXmlServerApi.requestSetFavorite(
      artistId: artist.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func searchArtists(searchText: String) async throws {
    guard isSyncAllowed, !searchText.isEmpty else { return }
    os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
    let response = try await ampacheXmlServerApi.requestSearchArtists(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = ArtistParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func searchAlbums(searchText: String) async throws {
    guard isSyncAllowed, !searchText.isEmpty else { return }
    os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
    let response = try await ampacheXmlServerApi.requestSearchAlbums(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = AlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func searchSongs(searchText: String) async throws {
    guard isSyncAllowed, !searchText.isEmpty else { return }
    os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
    let response = try await ampacheXmlServerApi.requestSearchSongs(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = IDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func parseLyrics(relFilePath: URL) async throws -> LyricsList {
    throw ResponseError(type: .xml, cleansedURL: nil, data: nil)
  }

  private func parseForError(response: APIDataResponse) throws {
    let parserDelegate = AmpacheXmlParser(performanceMonitor: performanceMonitor)
    try parse(response: response, delegate: parserDelegate)
  }

  nonisolated private func parse(
    response: APIDataResponse,
    delegate: AmpacheXmlParser,
    throwForNotFoundErrors: Bool = false,
    isThrowingErrorsAllowed: Bool = true
  ) throws {
    let parser = XMLParser(data: response.data)
    parser.delegate = delegate
    parser.parse()
    if let error = parser.parserError, isThrowingErrorsAllowed {
      os_log(
        "Error during response parsing: %s",
        log: self.log,
        type: .error,
        error.localizedDescription
      )
      throw ResponseError(
        type: .xml,
        cleansedURL: response.url?.asCleansedURL(cleanser: ampacheXmlServerApi),
        data: response.data
      )
    }
    if let error = delegate.error, let ampacheError = error.ampacheError, isThrowingErrorsAllowed,
       ampacheError.shouldErrorBeDisplayedToUser || throwForNotFoundErrors {
      throw ResponseError.createFromAmpacheError(
        cleansedURL: response.url?.asCleansedURL(cleanser: ampacheXmlServerApi),
        error: error,
        data: response.data
      )
    }
  }
}
