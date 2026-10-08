//
//  LibrarySyncerProxyTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 08.10.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

@testable import AmperfyKit
import XCTest

// MARK: - MOCK_CountingLibrarySyncer

/// A syncer that counts how often `sync(album:)` is entered and blocks each
/// entry on a gate the test opens explicitly, so a test can inspect how many
/// concurrent album syncs are in flight before letting them finish.
@MainActor
final class MOCK_CountingLibrarySyncer: LibrarySyncer {
  private(set) var albumSyncCount = 0
  private var gateContinuations = [CheckedContinuation<(), Never>]()
  var onAlbumSyncEntered: ((Int) -> ())?

  func openGate() {
    let continuations = gateContinuations
    gateContinuations.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
  }

  func sync(album: Album) async throws {
    albumSyncCount += 1
    onAlbumSyncEntered?(albumSyncCount)
    await withCheckedContinuation { continuation in
      gateContinuations.append(continuation)
    }
  }

  func syncInitial(statusNotifyier: SyncCallbacks?) async throws {}
  func sync(genre: Genre) async throws {}
  func sync(artist: Artist) async throws {}
  func sync(song: Song) async throws {}
  func sync(podcast: Podcast) async throws {}
  func syncNewestPodcastEpisodes() async throws {}
  func syncNewestAlbums(offset: Int, count: Int) async throws {}
  func syncRecentAlbums(offset: Int, count: Int) async throws {}
  func syncFavoriteLibraryElements() async throws {}
  func syncRadios() async throws {}
  func syncDownPlaylistsWithoutSongs() async throws {}
  func syncDown(playlist: Playlist) async throws {}
  func syncUpload(playlistToUpdateName playlist: Playlist) async throws {}
  func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws {}
  func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) async throws {}
  func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws {}
  func syncUpload(playlistIdToDelete id: String) async throws {}
  func syncDownPodcastsWithoutEpisodes() async throws {}
  func searchArtists(searchText: String) async throws {}
  func searchAlbums(searchText: String) async throws {}
  func searchSongs(searchText: String) async throws {}
  func syncMusicFolders() async throws {}
  func syncIndexes(musicFolder: MusicFolder) async throws {}
  func sync(directory: Directory) async throws {}
  func requestRandomSongs(playlist: Playlist, count: Int) async throws {}
  func requestSimilarSongs(song: Song, count: Int) async throws -> [Song] { [] }
  func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) async throws {}
  func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws {}
  func scrobble(song: Song, date: Date?) async throws {}
  func setRating(song: Song, rating: Int) async throws {}
  func setRating(album: Album, rating: Int) async throws {}
  func setRating(artist: Artist, rating: Int) async throws {}
  func setFavorite(song: Song, isFavorite: Bool) async throws {}
  func setFavorite(album: Album, isFavorite: Bool) async throws {}
  func setFavorite(artist: Artist, isFavorite: Bool) async throws {}
  func parseLyrics(relFilePath: URL) async throws -> LyricsList { LyricsList() }
}

// MARK: - MOCK_SingleSyncerBackendApi

/// A backend whose `createLibrarySyncer` always hands back the one shared
/// syncer, so the test can observe every album-sync call routed through the
/// proxy on a single counter.
final class MOCK_SingleSyncerBackendApi: BackendApi {
  let syncer: MOCK_CountingLibrarySyncer

  init(syncer: MOCK_CountingLibrarySyncer) {
    self.syncer = syncer
  }

  let clientApiVersion = ""
  let serverApiVersion = ""
  let httpHeaders = [String: String]()
  func provideCredentials(credentials: LoginCredentials) {}
  func isAuthenticationValid(credentials: LoginCredentials) async throws {}
  func generateUrl(forDownloadingPlayable playableInfo: AbstractPlayableInfo) async throws -> URL {
    URL(string: "https://amperfy.example")!
  }

  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL { URL(string: "https://amperfy.example")! }
  func generateUrl(forArtwork artwork: Artwork) async throws -> URL {
    URL(string: "https://amperfy.example")!
  }

  func checkForErrorResponse(response: APIDataResponse) -> ResponseError? { nil }
  func createLibrarySyncer(account: Account, storage: PersistentStorage) -> LibrarySyncer { syncer }
  func createArtworkDownloadDelegate() -> DownloadManagerDelegate { MOCK_DownloadManagerDelegate() }
  func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? { nil }
  func cleanse(url: URL?) -> CleansedURL { CleansedURL(urlString: "") }
}

// MARK: - LibrarySyncerProxyTest

@MainActor
class LibrarySyncerProxyTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var storage: PersistentStorage!
  var syncer: MOCK_CountingLibrarySyncer!
  var proxy: LibrarySyncerProxy!
  var album: Album!
  var otherAlbum: Album!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    let coreDataManager = MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    storage = PersistentStorage(coreDataManager: coreDataManager)
    syncer = MOCK_CountingLibrarySyncer()
    proxy = LibrarySyncerProxy(
      backendApi: MOCK_SingleSyncerBackendApi(syncer: syncer),
      account: account,
      storage: storage
    )
    // Two distinct albums that share the same (empty) server id: an unsynced
    // album carries id "", so keying the coalescing on the server id would
    // wrongly merge them. See testDistinctAlbumsWithSameServerIdAreNotCoalesced.
    album = library.createAlbum(account: account)
    album.id = ""
    otherAlbum = library.createAlbum(account: account)
    otherAlbum.id = ""
    library.saveContext()
  }

  override func tearDown() {}

  /// Two overlapping syncs of the same album must fetch it only once. On the
  /// unfixed proxy the second call enters the syncer too (count == 2), which
  /// fulfills the inverted expectation and fails the test (upstream issue #778).
  func testConcurrentSyncOfSameAlbumRunsOnce() async throws {
    let firstEntered = expectation(description: "first album sync entered")
    let secondMustNotEnter = expectation(description: "second album sync must not enter")
    secondMustNotEnter.isInverted = true
    syncer.onAlbumSyncEntered = { count in
      if count == 1 { firstEntered.fulfill() }
      if count >= 2 { secondMustNotEnter.fulfill() }
    }

    let first = Task { @MainActor in try await self.proxy.sync(album: self.album) }
    await fulfillment(of: [firstEntered], timeout: 2)

    let second = Task { @MainActor in try await self.proxy.sync(album: self.album) }
    await fulfillment(of: [secondMustNotEnter], timeout: 1)
    XCTAssertEqual(syncer.albumSyncCount, 1)

    syncer.openGate()
    try await first.value
    try await second.value
    XCTAssertEqual(syncer.albumSyncCount, 1)
  }

  /// A sync started after the previous one finished must fetch the album again;
  /// coalescing only applies while a sync is in flight.
  func testSyncAfterCompletionRunsAgain() async throws {
    let firstEntered = expectation(description: "first album sync entered")
    syncer.onAlbumSyncEntered = { count in
      if count == 1 { firstEntered.fulfill() }
    }
    let first = Task { @MainActor in try await self.proxy.sync(album: self.album) }
    await fulfillment(of: [firstEntered], timeout: 2)
    syncer.openGate()
    try await first.value
    XCTAssertEqual(syncer.albumSyncCount, 1)

    let secondEntered = expectation(description: "second album sync entered")
    syncer.onAlbumSyncEntered = { count in
      if count == 2 { secondEntered.fulfill() }
    }
    let second = Task { @MainActor in try await self.proxy.sync(album: self.album) }
    await fulfillment(of: [secondEntered], timeout: 2)
    syncer.openGate()
    try await second.value
    XCTAssertEqual(syncer.albumSyncCount, 2)
  }

  /// Two different albums that happen to share a server id (here the empty id
  /// of unsynced albums) must each be synced; coalescing keys on the local
  /// object identity, not the server id. Keying on the server id would merge
  /// them and this test would time out at one sync.
  func testDistinctAlbumsWithSameServerIdAreNotCoalesced() async throws {
    let bothEntered = expectation(description: "both albums entered the syncer")
    bothEntered.expectedFulfillmentCount = 2
    syncer.onAlbumSyncEntered = { _ in bothEntered.fulfill() }

    let first = Task { @MainActor in try await self.proxy.sync(album: self.album) }
    let second = Task { @MainActor in try await self.proxy.sync(album: self.otherAlbum) }
    await fulfillment(of: [bothEntered], timeout: 2)
    XCTAssertEqual(syncer.albumSyncCount, 2)

    syncer.openGate()
    try await first.value
    try await second.value
  }
}
