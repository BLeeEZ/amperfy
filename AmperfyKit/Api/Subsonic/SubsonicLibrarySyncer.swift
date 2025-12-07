//
//  SubsonicLibrarySyncer.swift
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

class SubsonicLibrarySyncer: CommonLibrarySyncer, LibrarySyncer {
  private let subsonicServerApi: SubsonicServerApi

  private static let maxItemCountToPollAtOnce: Int = 500

  init(
    subsonicServerApi: SubsonicServerApi,
    account: Account,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    storage: PersistentStorage,
    eventLogger: EventLogger
  ) {
    self.subsonicServerApi = subsonicServerApi
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

    statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: 0)
    let genreResponse = try await subsonicServerApi.requestGenres()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: genreResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsGenreParserDelegate(
        performanceMonitor: self.performanceMonitor,
        prefetch: prefetch,
        account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: statusNotifyier
      )
      try self.parse(
        response: genreResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
    }

    statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: 0)
    let artistsResponse = try await subsonicServerApi.requestArtists()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: artistsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsArtistParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library,
        parseNotifier: statusNotifyier
      )
      try self.parse(
        response: artistsResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
    }

    var pollCountArtist = 0
    storage.main.perform { companion in
      let accountAsync = companion.library.getAccount(managedObjectId: self.accountObjectId)
      let artists = companion.library.getArtists(for: accountAsync).filter { !$0.id.isEmpty }
      let albumCount = artists.reduce(0) { $0 + $1.remoteAlbumCount }
      pollCountArtist = max(
        1,
        Int(ceil(Double(albumCount) / Double(Self.maxItemCountToPollAtOnce)))
      )
    }
    statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: pollCountArtist)
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for index in Array(0 ... pollCountArtist) {
        taskGroup.addTask { @MainActor @Sendable in
          let albumsResponse = try await self.subsonicServerApi.requestAlbums(
            offset: index * Self.maxItemCountToPollAtOnce,
            count: Self.maxItemCountToPollAtOnce
          )
          try await self.storage.async.perform { asyncCompanion in
            let accountAsync = Account(
              managedObject: asyncCompanion.context
                .object(with: self.accountObjectId) as! AccountMO
            )
            let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
            try self.parse(
              response: albumsResponse,
              delegate: idParserDelegate,
              isThrowingErrorsAllowed: false
            )
            let prefetch = asyncCompanion.library
              .getElements(account: accountAsync, prefetchIDs: idParserDelegate.prefetchIDs)

            let parserDelegate = SsAlbumParserDelegate(
              performanceMonitor: self.performanceMonitor, prefetch: prefetch,
              account: accountAsync,
              library: asyncCompanion.library,
              parseNotifier: statusNotifyier
            )
            parserDelegate.prefetch = prefetch
            try self.parse(
              response: albumsResponse,
              delegate: parserDelegate,
              isThrowingErrorsAllowed: false
            )
          }
          statusNotifyier?.notifyParsedObject(ofType: .album)
        }
      }
      try await taskGroup.waitForAll()
    }

    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      // Delete duplicated artists due to concurrence
      let allArtists = asyncCompanion.library.getArtists(for: accountAsync)
      var uniqueArtists: [String: Artist] = [:]
      for artist in allArtists {
        if uniqueArtists[artist.id] != nil {
          let artistAlbums = artist.albums
          artistAlbums.forEach { $0.artist = uniqueArtists[artist.id] }
          os_log(
            "Delete multiple Artist <%s> with id %s",
            log: self.log,
            type: .info,
            artist.name,
            artist.id
          )
          asyncCompanion.library.deleteArtist(artist: artist)
        } else {
          uniqueArtists[artist.id] = artist
        }
      }
      // Delete duplicated albums due to concurrence
      let albums = asyncCompanion.library.getAlbums(for: accountAsync)
      var uniqueAlbums: [String: Album] = [:]
      for album in albums {
        if uniqueAlbums[album.id] != nil {
          asyncCompanion.library.deleteAlbum(album: album)
        } else {
          uniqueAlbums[album.id] = album
        }
      }
    }

    statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: 0)
    let playlistsResponse = try await subsonicServerApi.requestPlaylists()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let parserDelegate = SsPlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(
        response: playlistsResponse,
        delegate: parserDelegate,
        isThrowingErrorsAllowed: false
      )
    }

    let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: 0)
    let podcastsResponse = try await subsonicServerApi.requestPodcasts()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: podcastsResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsPodcastParserDelegate(
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
      genre.albums.forEach { album in
        taskGroup.addTask { @MainActor @Sendable in
          try await self.sync(album: album)
        }
      }
      try await taskGroup.waitForAll()
    }
  }

  @MainActor
  func sync(artist: Artist) async throws {
    guard isSyncAllowed, !artist.id.isEmpty, artist.remoteStatus != .deleted else { return }
    let artistObjectId = artist.managedObject.objectID

    func handleNotAvailableArtist(error: Error) async throws {
      try await storage.async.perform { asyncCompanion in
        if let responseError = error as? ResponseError,
           let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
          let artistAsync = Artist(
            managedObject: asyncCompanion.context
              .object(with: artistObjectId) as! ArtistMO
          )
          let reportError = ResponseError(
            type: .resource,
            statusCode: responseError.statusCode,
            message: "Artist \"\(artistAsync.name)\" is no longer available on the server.",
            cleansedURL: responseError.cleansedURL,
            data: responseError.data
          )
          artistAsync.remoteStatus = .deleted
          throw reportError
        }
      }
      throw error
    }

    var artistResponse: APIDataResponse?
    do {
      artistResponse = try await subsonicServerApi.requestArtist(id: artist.id)
    } catch {
      try await handleNotAvailableArtist(error: error)
    }
    guard let artistResponse else { return }

    do {
      try await storage.async.perform { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: self.accountObjectId) as! AccountMO
        )
        let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(
          response: artistResponse,
          delegate: idParserDelegate,
          isThrowingErrorsAllowed: false
        )
        let prefetch = asyncCompanion.library.getElements(
          account: accountAsync,
          prefetchIDs: idParserDelegate.prefetchIDs
        )

        let parserDelegate = SsArtistParserDelegate(
          performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
          library: asyncCompanion.library
        )
        try self.parse(response: artistResponse, delegate: parserDelegate)
      }
    } catch {
      try await handleNotAvailableArtist(error: error)
    }

    guard artist.remoteStatus == .available else { return }
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      artist.albums.forEach { album in
        taskGroup.addTask { @MainActor @Sendable in
          try await self.sync(album: album)
        }
      }
      try await taskGroup.waitForAll()
    }
  }

  @MainActor
  func sync(album: Album) async throws {
    guard isSyncAllowed, album.remoteStatus != .deleted else { return }
    let albumObjectId = album.managedObject.objectID

    func handleNotAvailableAlbum(error: Error) async throws {
      try await storage.async.perform { asyncCompanion in
        if let responseError = error as? ResponseError,
           let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
          let albumAsync = Album(
            managedObject: asyncCompanion.context
              .object(with: albumObjectId) as! AlbumMO
          )
          let reportError = ResponseError(
            type: .resource,
            statusCode: responseError.statusCode,
            message: "Album \"\(albumAsync.name)\" is no longer available on the server.",
            cleansedURL: responseError.cleansedURL,
            data: responseError.data
          )
          albumAsync.markAsRemoteDeleted()
          throw reportError
        }
      }
      throw error
    }

    var albumResponse: APIDataResponse?
    do {
      albumResponse = try await subsonicServerApi.requestAlbum(id: album.id)
    } catch {
      try await handleNotAvailableAlbum(error: error)
    }
    guard let albumResponse else { return }

    do {
      try await storage.async.perform { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: self.accountObjectId) as! AccountMO
        )
        let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(
          response: albumResponse,
          delegate: idParserDelegate,
          isThrowingErrorsAllowed: false
        )
        let prefetch = asyncCompanion.library.getElements(
          account: accountAsync,
          prefetchIDs: idParserDelegate.prefetchIDs
        )

        let parserDelegate = SsAlbumParserDelegate(
          performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
          library: asyncCompanion.library
        )
        try self.parse(response: albumResponse, delegate: parserDelegate)
      }
    } catch {
      try await handleNotAvailableAlbum(error: error)
    }

    guard album.remoteStatus == .available else { return }
    try await storage.async.perform { asyncCompanion in
      let albumAsync = Album(
        managedObject: asyncCompanion.context
          .object(with: albumObjectId) as! AlbumMO
      )
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let oldSongs = Set(albumAsync.songs)

      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: albumResponse,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )
      let parserDelegate = SsSongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: albumResponse, delegate: parserDelegate)
      let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
      removedSongs.lazy.compactMap { $0.asSong }.forEach {
        os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
        $0.remoteStatus = .deleted
        albumAsync.managedObject.removeFromSongs($0.managedObject)
      }
      albumAsync.isCached = parserDelegate.isCollectionCached
      albumAsync.isSongsMetaDataSynced = true
    }
  }

  @MainActor
  func sync(song: Song) async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestSongInfo(id: song.id)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = Account(
        managedObject: asyncCompanion.context
          .object(with: self.accountObjectId) as! AccountMO
      )
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsSongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
    try await syncLyrics(song: song)
  }

  @MainActor
  private func syncLyrics(song: Song) async throws {
    do {
      let isSupported = await subsonicServerApi
        .isOpenSubsonicExtensionSupported(extension: .songLyrics)
      guard isSupported else { return }
      let response = try await subsonicServerApi.requestLyricsBySongId(id: song.id)
      let songObjectId = song.managedObject.objectID
      try await storage.async.perform { asyncCompanion in
        guard let songAsyncMO = asyncCompanion.context.object(with: songObjectId) as? SongMO,
              let accountAsyncMO = asyncCompanion.context
              .object(with: self.accountObjectId) as? AccountMO
        else { return }
        let songAsync = Song(managedObject: songAsyncMO)
        let accountAsync = Account(managedObject: accountAsyncMO)

        guard let lyricsRelFilePath = self.fileManager.createRelPath(forLyricsOf: songAsync),
              let lyricsAbsFilePath = self.fileManager
              .getAbsoluteAmperfyPath(relFilePath: lyricsRelFilePath)
        else { return }

        let parserDelegate = SsLyricsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
        // save xml response only if it contains valid lyrics
        if (parserDelegate.lyricsList?.lyrics.count ?? 0) > 0 {
          do {
            try self.fileManager.writeDataExcludedFromBackup(
              data: response.data,
              to: lyricsAbsFilePath,
              accountInfo: accountAsync.info
            )
            songAsync.lyricsRelFilePath = lyricsRelFilePath
            os_log(
              "Lyrics found for <%s> and saved to: %s",
              log: self.log,
              type: .info,
              songAsync.displayString,
              lyricsRelFilePath.path
            )
          } catch {
            songAsync.lyricsRelFilePath = nil
          }
        } else {
          os_log(
            "No lyrics available for <%s>",
            log: self.log,
            type: .info,
            songAsync.displayString
          )
        }
      }
    } catch {
      // do nothing
    }
  }

  @MainActor
  func sync(podcast: Podcast) async throws {
    guard isSyncAllowed, podcast.remoteStatus != .deleted else { return }
    let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    let podcastObjectId = podcast.managedObject.objectID

    func handleNotAvailablePodcast(podcastObjectId: NSManagedObjectID, error: Error) async throws {
      try await storage.async.perform { asyncCompanion in
        if let responseError = error as? ResponseError,
           let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
          let podcastAsync = Podcast(
            managedObject: asyncCompanion.context
              .object(with: podcastObjectId) as! PodcastMO
          )
          let reportError = ResponseError(
            type: .resource,
            statusCode: responseError.statusCode,
            message: "Podcast \"\(podcastAsync.name)\" is no longer available on the server.",
            cleansedURL: responseError.cleansedURL,
            data: responseError.data
          )
          podcastAsync.remoteStatus = .deleted
          throw reportError
        }
      }
      throw error
    }

    var podcastResponse: APIDataResponse?
    do {
      podcastResponse = try await subsonicServerApi.requestPodcastEpisodes(id: podcast.id)
    } catch {
      try await handleNotAvailablePodcast(podcastObjectId: podcastObjectId, error: error)
    }
    guard let podcastResponse else { return }

    do {
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

        let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(
          response: podcastResponse,
          delegate: idParserDelegate,
          isThrowingErrorsAllowed: false
        )
        let prefetch = asyncCompanion.library.getElements(
          account: accountAsync,
          prefetchIDs: idParserDelegate.prefetchIDs
        )

        let parserDelegate = SsPodcastEpisodeParserDelegate(
          performanceMonitor: self.performanceMonitor,
          podcast: podcastAsync, prefetch: prefetch, account: accountAsync,
          library: asyncCompanion.library
        )
        try self.parse(response: podcastResponse, delegate: parserDelegate)
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
    } catch {
      try await handleNotAvailablePodcast(podcastObjectId: podcastObjectId, error: error)
    }
  }

  @MainActor
  func syncNewestPodcastEpisodes() async throws {
    guard isSyncAllowed else { return }
    os_log("Sync newest podcast episodes", log: log, type: .info)
    let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
    guard isSupported else { return }
    try await syncDownPodcastsWithoutEpisodes()
    let response = try await subsonicServerApi.requestNewestPodcasts()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsPodcastEpisodeParserDelegate(
        performanceMonitor: self.performanceMonitor,
        podcast: nil, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      parserDelegate.performPostParseOperations()
    }
  }

  @MainActor
  func syncNewestAlbums(offset: Int, count: Int) async throws {
    guard isSyncAllowed else { return }
    os_log("Sync newest albums: offset: %i count: %i", log: log, type: .info, offset, count)
    let response = try await subsonicServerApi.requestNewestAlbums(offset: offset, count: count)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsAlbumParserDelegate(
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
      parserDelegate.parsedAlbums.enumerated().forEach { index, album in
        album.updateIsNewestInfo(index: index + 1 + offset)
      }
    }
  }

  @MainActor
  func syncRecentAlbums(offset: Int, count: Int) async throws {
    guard isSyncAllowed else { return }
    os_log("Sync recent albums: offset: %i count: %i", log: log, type: .info, offset, count)
    let response = try await subsonicServerApi.requestRecentAlbums(offset: offset, count: count)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsAlbumParserDelegate(
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
      parserDelegate.parsedAlbums.enumerated().forEach { index, album in
        album.updateIsRecentInfo(index: index + 1 + offset)
      }
    }
  }

  @MainActor
  func syncFavoriteLibraryElements() async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestFavoriteElements()
    try await storage.async.perform { asyncCompanion in
      os_log("Sync favorite artists", log: self.log, type: .info)
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldFavoriteArtists = Set(asyncCompanion.library.getFavoriteArtists(for: accountAsync))
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )
      let parserDelegateArtist = SsArtistParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegateArtist)
      let notFavoriteArtistsAnymore = oldFavoriteArtists
        .subtracting(parserDelegateArtist.parsedArtists)
      notFavoriteArtistsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }

      os_log("Sync favorite albums", log: self.log, type: .info)
      let oldFavoriteAlbums = Set(asyncCompanion.library.getFavoriteAlbums(for: accountAsync))
      let parserDelegateAlbum = SsAlbumParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegateAlbum)
      let notFavoriteAlbumsAnymore = oldFavoriteAlbums.subtracting(parserDelegateAlbum.parsedAlbums)
      notFavoriteAlbumsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }

      os_log("Sync favorite songs", log: self.log, type: .info)
      let oldFavoriteSongs = Set(asyncCompanion.library.getFavoriteSongs(for: accountAsync))
      let parserDelegateSong = SsSongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegateSong)
      let notFavoriteSongsAnymore = oldFavoriteSongs.subtracting(parserDelegateSong.parsedSongs)
      notFavoriteSongsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
    }
  }

  @MainActor
  func syncRadios() async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestRadios()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldRadios = Set(asyncCompanion.library.getRadios(for: accountAsync))

      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsRadioParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
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
  func syncMusicFolders() async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestMusicFolders()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsMusicFolderParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func syncIndexes(musicFolder: MusicFolder) async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestIndexes(musicFolderId: musicFolder.id)
    let musicFolderObjectId = musicFolder.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let musicFolderAsync = MusicFolder(
        managedObject: asyncCompanion.context
          .object(with: musicFolderObjectId) as! MusicFolderMO
      )
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsDirectoryParserDelegate(
        performanceMonitor: self.performanceMonitor,
        musicFolder: musicFolderAsync, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      musicFolderAsync.isCached = parserDelegate.isCollectionCached
    }
  }

  @MainActor
  func sync(directory: Directory) async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestMusicDirectory(id: directory.id)
    let directoryObjectId = directory.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let directoryAsync = Directory(
        managedObject: asyncCompanion.context
          .object(with: directoryObjectId) as! DirectoryMO
      )
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsDirectoryParserDelegate(
        performanceMonitor: self.performanceMonitor,
        directory: directoryAsync, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
      directoryAsync.isCached = parserDelegate.isCollectionCached
    }
  }

  @MainActor
  func requestRandomSongs(playlist: Playlist, count: Int) async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestRandomSongs(count: count)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsSongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
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
    let response = try await subsonicServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
    try parseForError(response: response)
  }

  @MainActor
  func syncDownPlaylistsWithoutSongs() async throws {
    guard isSyncAllowed else { return }
    let response = try await subsonicServerApi.requestPlaylists()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let parserDelegate = SsPlaylistParserDelegate(
        performanceMonitor: self.performanceMonitor, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func syncDown(playlist: Playlist) async throws {
    guard isSyncAllowed, playlist.id != "" else { return }
    os_log("Playlist \"%s\": Download songs from server", log: self.log, type: .info, playlist.name)
    let response = try await subsonicServerApi.requestPlaylistSongs(id: playlist.id)

    os_log("Playlist \"%s\": Parse songs start", log: self.log, type: .info, playlist.name)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )

      let idsParserDelegate = SsIDsParserDelegate(
        performanceMonitor: self.performanceMonitor
      )
      try self.parse(response: response, delegate: idsParserDelegate)
      let prefetch = asyncCompanion.library
        .getElements(account: accountAsync, prefetchIDs: idsParserDelegate.prefetchIDs)

      let parserDelegate = SsPlaylistSongsParserDelegate(
        performanceMonitor: self.performanceMonitor,
        playlist: playlistAsync, account: accountAsync,
        library: asyncCompanion.library, prefetch: prefetch
      )
      try self.parse(response: response, delegate: parserDelegate)
      playlistAsync.isCached = parserDelegate.isCollectionCached
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
  private func validatePlaylistId(playlist: Playlist) async throws {
    if playlist.id == "" {
      try await createPlaylistRemote(playlist: playlist)
    }
    if playlist.id == "" {
      os_log("Playlist id was not assigned after creation", log: self.log, type: .info)
      throw BackendError
        .incorrectServerBehavior(message: "Playlist id was not assigned after creation")
    }
  }

  @MainActor
  func syncUpload(playlistToUpdateName playlist: Playlist) async throws {
    guard isSyncAllowed else { return }
    os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
    try await validatePlaylistId(playlist: playlist)
    let response = try await subsonicServerApi.requestPlaylistUpdate(
      id: playlist.id,
      name: playlist.name,
      songIndicesToRemove: [],
      songIdsToAdd: []
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws {
    guard isSyncAllowed, !songs.isEmpty else { return }
    os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
    try await validatePlaylistId(playlist: playlist)
    let response = try await subsonicServerApi.requestPlaylistUpdate(
      id: playlist.id,
      name: playlist.name,
      songIndicesToRemove: [],
      songIdsToAdd: songs.compactMap { $0.id }
    )
    try parseForError(response: response)
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
    let response = try await subsonicServerApi.requestPlaylistUpdate(
      id: playlist.id,
      name: playlist.name,
      songIndicesToRemove: [index],
      songIdsToAdd: []
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws {
    guard isSyncAllowed else { return }
    os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
    try await validatePlaylistId(playlist: playlist)
    let songIdsToAdd = playlist.playables.compactMap { $0.id }
    let songIndicesToRemove = Array(0 ... songIdsToAdd.count - 1)
    let response = try await subsonicServerApi.requestPlaylistUpdate(
      id: playlist.id,
      name: playlist.name,
      songIndicesToRemove: songIndicesToRemove,
      songIdsToAdd: songIdsToAdd
    )
    try parseForError(response: response)
  }

  @MainActor
  func syncUpload(playlistIdToDelete id: String) async throws {
    guard isSyncAllowed else { return }
    os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
    let response = try await subsonicServerApi.requestPlaylistDelete(id: id)
    try parseForError(response: response)
  }

  @MainActor
  func syncDownPodcastsWithoutEpisodes() async throws {
    guard isSyncAllowed else { return }
    let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
    guard isSupported else { return }

    let response = try await subsonicServerApi.requestPodcasts()
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let oldPodcasts = Set(asyncCompanion.library.getRemoteAvailablePodcasts(for: accountAsync))

      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsPodcastParserDelegate(
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

  @MainActor
  func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws {
    guard isSyncAllowed else { return }
    switch songPosition {
    case .start:
      return try await scrobble(song: song, submission: false)
    case .end:
      return try await scrobble(song: song, submission: true)
    }
  }

  @MainActor
  func scrobble(song: Song, date: Date?) async throws {
    try await scrobble(song: song, submission: true, date: date)
  }

  @MainActor
  private func scrobble(song: Song, submission: Bool, date: Date? = nil) async throws {
    guard isSyncAllowed else { return }
    if !submission {
      os_log("Now Playing Begin: %s", log: log, type: .info, song.displayString)
    } else if let date = date {
      os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
    } else {
      os_log("Now Playing End (Scrobble): %s", log: log, type: .info, song.displayString)
    }
    let response = try await subsonicServerApi.requestScrobble(
      id: song.id,
      submission: submission,
      date: date
    )
    try parseForError(response: response)
  }

  @MainActor
  func setRating(song: Song, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
    let response = try await subsonicServerApi.requestRating(id: song.id, rating: rating)
    try parseForError(response: response)
  }

  @MainActor
  func setRating(album: Album, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
    let response = try await subsonicServerApi.requestRating(id: album.id, rating: rating)
    try parseForError(response: response)
  }

  @MainActor
  func setRating(artist: Artist, rating: Int) async throws {
    guard isSyncAllowed, rating >= 0, rating <= 5 else { return }
    os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
    let response = try await subsonicServerApi.requestRating(id: artist.id, rating: rating)
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
    let response = try await subsonicServerApi.requestSetFavorite(
      songId: song.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func setFavorite(album: Album, isFavorite: Bool) async throws {
    guard isSyncAllowed else { return }
    os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
    let response = try await subsonicServerApi.requestSetFavorite(
      albumId: album.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func setFavorite(artist: Artist, isFavorite: Bool) async throws {
    guard isSyncAllowed else { return }
    os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
    let response = try await subsonicServerApi.requestSetFavorite(
      artistId: artist.id,
      isFavorite: isFavorite
    )
    try parseForError(response: response)
  }

  @MainActor
  func searchArtists(searchText: String) async throws {
    guard isSyncAllowed, !searchText.isEmpty else { return }
    os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
    let response = try await subsonicServerApi.requestSearchArtists(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsArtistParserDelegate(
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
    let response = try await subsonicServerApi.requestSearchAlbums(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsAlbumParserDelegate(
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
    let response = try await subsonicServerApi.requestSearchSongs(searchText: searchText)
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsSongParserDelegate(
        performanceMonitor: self.performanceMonitor, prefetch: prefetch, account: accountAsync,
        library: asyncCompanion.library
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
  }

  @MainActor
  func parseLyrics(relFilePath: URL) async throws -> LyricsList {
    let parserDelegate = SsLyricsParserDelegate(performanceMonitor: performanceMonitor)
    guard let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) else {
      throw ResponseError(type: .xml)
    }
    do {
      try parse(absFilePath: absFilePath, delegate: parserDelegate, isThrowingErrorsAllowed: false)
    } catch {
      throw ResponseError(type: .xml)
    }
    guard let lyricsList = parserDelegate.lyricsList else {
      throw ResponseError(type: .xml)
    }
    return lyricsList
  }

  @MainActor
  private func createPlaylistRemote(playlist: Playlist) async throws {
    os_log("Create playlist on server", log: log, type: .info)
    let response = try await subsonicServerApi.requestPlaylistCreate(name: playlist.name)
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )

      let idParserDelegate = SsIDsParserDelegate(performanceMonitor: self.performanceMonitor)
      try self.parse(
        response: response,
        delegate: idParserDelegate,
        isThrowingErrorsAllowed: false
      )
      let prefetch = asyncCompanion.library.getElements(
        account: accountAsync,
        prefetchIDs: idParserDelegate.prefetchIDs
      )

      let parserDelegate = SsPlaylistSongsParserDelegate(
        performanceMonitor: self.performanceMonitor,
        playlist: playlistAsync, account: accountAsync,
        library: asyncCompanion.library, prefetch: prefetch
      )
      try self.parse(response: response, delegate: parserDelegate)
    }
    // Old api version -> need to match the created playlist via name
    if playlist.id == "" {
      try await updatePlaylistIdViaItsName(playlist: playlist)
    }
  }

  @MainActor
  private func updatePlaylistIdViaItsName(playlist: Playlist) async throws {
    try await syncDownPlaylistsWithoutSongs()
    let playlistObjectId = playlist.managedObject.objectID
    try await storage.async.perform { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let playlistAsync = Playlist(
        library: asyncCompanion.library,
        managedObject: asyncCompanion.context.object(with: playlistObjectId) as! PlaylistMO
      )
      let playlists = asyncCompanion.library.getPlaylists(for: accountAsync)
      let nameMatchingPlaylists = playlists.filter { filterPlaylist in
        filterPlaylist.name == playlistAsync.name && filterPlaylist.id != ""
      }
      guard !nameMatchingPlaylists.isEmpty,
            let firstMatch = nameMatchingPlaylists.first else { return }
      let matchedId = firstMatch.id
      asyncCompanion.library.deletePlaylist(firstMatch)
      playlistAsync.id = matchedId
    }
  }

  private func parseForError(response: APIDataResponse) throws {
    let parserDelegate = SsPingParserDelegate(performanceMonitor: performanceMonitor)
    try parse(response: response, delegate: parserDelegate)
  }

  nonisolated private func parse(
    response: APIDataResponse,
    delegate: SsXmlParser,
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
        cleansedURL: response.url?.asCleansedURL(cleanser: subsonicServerApi),
        data: response.data
      )
    }
    if let error = delegate.error, let _ = error.subsonicError, isThrowingErrorsAllowed {
      throw ResponseError.createFromSubsonicError(
        cleansedURL: response.url?.asCleansedURL(cleanser: subsonicServerApi),
        error: error,
        data: response.data
      )
    }
  }

  nonisolated private func parse(
    absFilePath: URL,
    delegate: SsXmlParser,
    isThrowingErrorsAllowed: Bool = true
  ) throws {
    guard let parser = XMLParser(contentsOf: absFilePath) else {
      throw ResponseError(type: .xml)
    }
    parser.delegate = delegate
    parser.parse()
    if let error = parser.parserError, isThrowingErrorsAllowed {
      os_log(
        "Error during response parsing: %s",
        log: self.log,
        type: .error,
        error.localizedDescription
      )
      throw ResponseError(type: .xml)
    }
    if let error = delegate.error, let _ = error.subsonicError, isThrowingErrorsAllowed {
      throw ResponseError(type: .xml)
    }
  }
}
