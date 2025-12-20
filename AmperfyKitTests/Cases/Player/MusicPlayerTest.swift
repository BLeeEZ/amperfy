//
//  MusicPlayerTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 12.01.20.
//  Copyright (c) 2020 Maximilian Bauer. All rights reserved.
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
@preconcurrency @testable import AudioStreaming
import AVFoundation
import CoreData
import XCTest

// MARK: - MOCK_AudioStreamingPlayer

class MOCK_AudioStreamingPlayer: AudioStreamingPlayer {
  static nonisolated(unsafe) private var delegateBackup: AudioPlayerDelegate?

  nonisolated(unsafe) private var _mockElapsedTime: Double = 0.0
  private let _mockElapsedTimeLock = NSLock()
  nonisolated public var mockElapsedTime: Double {
    get {
      _mockElapsedTimeLock.withLock { _mockElapsedTime }
    }
    set {
      _mockElapsedTimeLock.withLock { _mockElapsedTime = newValue }
    }
  }

  nonisolated(unsafe) private var _isPlaying = false
  private let _isPlayingLock = NSLock()
  nonisolated public var isPlaying: Bool {
    get {
      _isPlayingLock.withLock { _isPlaying }
    }
    set {
      _isPlayingLock.withLock { _isPlaying = newValue }
    }
  }

  nonisolated(unsafe) private var _isStopped = true
  private let _isStoppedLock = NSLock()
  nonisolated public var isStopped: Bool {
    get {
      _isStoppedLock.withLock { _isStopped }
    }
    set {
      _isStoppedLock.withLock { _isStopped = newValue }
    }
  }

  override func play(url: URL) {
    Self.delegateBackup = delegate
    mockElapsedTime = 0.0
    isPlaying = true
    isStopped = false
    let currId = url.absoluteString
    Task { @MainActor [currId] in
      let entryID = AudioEntryId(id: currId)
      Self.delegateBackup?.audioPlayerDidStartPlaying(
        player: AudioStreaming.AudioPlayer(),
        with: entryID
      )
    }
  }

  override func pause() {
    isPlaying = false
  }

  override func stop(clearQueue: Bool = true) {
    isPlaying = false
    isStopped = true
  }

  override func queue(url: URL) {}
  override func seek(to time: Double) {
    mockElapsedTime = time
  }

  override func elapsedTime() -> Double {
    mockElapsedTime
  }

  override func getState() -> AudioStreaming.AudioPlayerState {
    isStopped ? .stopped : (isPlaying ? .playing : .paused)
  }
}

// MARK: - MOCK_SongDownloader

class MOCK_SongDownloader: DownloadManageable {
  var urlSessionIdentifier: String? {
    ""
  }

  var downloadables = [Downloadable]()
  func isNoDownloadRequested() -> Bool {
    downloadables.isEmpty
  }

  func getBackgroundFetchCompletionHandler() async -> AmperfyKit.CompleteHandlerBlock? { nil }
  func setBackgroundFetchCompletionHandler(_ newValue: AmperfyKit.CompleteHandlerBlock?) {}
  func download(object: Downloadable) { downloadables.append(object) }
  func download(objects: [Downloadable]) { downloadables.append(contentsOf: objects) }
  func removeFinishedDownload(for object: Downloadable) {}
  func removeFinishedDownload(for objects: [Downloadable]) {}
  func clearFinishedDownloads() {}
  func resetFailedDownloads() {}
  func cancelDownloads() {}
  func start() {}
  func stop() {}
}

// MARK: - MOCK_AlertDisplayable

class MOCK_AlertDisplayable: AlertDisplayable {
  func display(
    title: String,
    subtitle: String,
    style: LogEntryType,
    notificationBanner popupVC: UIViewController
  ) {}
  func display(popup popupVC: UIViewController) {}
  func createPopupVC(
    topic: String,
    shortMessage: String,
    detailMessage: String,
    logType: AmperfyKit.LogEntryType
  )
    -> UIViewController { UIViewController() }
}

// MARK: - MOCK_LibrarySyncer

final class MOCK_LibrarySyncer: LibrarySyncer {
  func syncInitial(statusNotifyier: SyncCallbacks?) async throws {}
  func sync(genre: Genre) async throws {}
  func sync(artist: Artist) async throws {}
  func sync(album: Album) async throws {}
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

// MARK: - MOCK_DownloadManagerDelegate

final class MOCK_DownloadManagerDelegate: DownloadManagerDelegate {
  var requestPredicate: NSPredicate { NSPredicate(value: true) }
  let parallelDownloadsCount = 2
  func prepareDownload(
    downloadInfo: AmperfyKit.DownloadElementInfo,
    storage: AmperfyKit.AsyncCoreDataAccessWrapper
  ) async throws
    -> URL {
    throw BackendError.notSupported
  }

  func validateDownloadedData(fileURL: URL?, downloadURL: URL?) -> ResponseError? { nil }
  func completedDownload(
    downloadInfo: AmperfyKit.DownloadElementInfo,
    fileURL: URL,
    fileMimeType: String?,
    storage: AmperfyKit.AsyncCoreDataAccessWrapper
  ) async {}

  func failedDownload(
    downloadInfo: AmperfyKit.DownloadElementInfo,
    storage: AmperfyKit.AsyncCoreDataAccessWrapper
  ) async {}
}

// MARK: - MOCK_BackendApi

final class MOCK_BackendApi: BackendApi {
  let clientApiVersion: String = ""
  let serverApiVersion: String = ""
  func provideCredentials(credentials: LoginCredentials) {}
  func isAuthenticationValid(credentials: LoginCredentials) async throws {
    throw BackendError.notSupported
  }

  func generateUrl(
    forDownloadingPlayable playableInfo: AbstractPlayableInfo
  ) async throws
    -> URL {
    Helper.testURL
  }

  func generateUrl(
    forStreamingPlayable playableInfo: AbstractPlayableInfo,
    maxBitrate: StreamingMaxBitratePreference,
    formatPreference: StreamingFormatPreference
  ) async throws
    -> URL { Helper.testURL }

  func generateUrl(forArtwork artwork: Artwork) async throws -> URL { Helper.testURL }
  func checkForErrorResponse(response: APIDataResponse) -> ResponseError? { nil }
  func createLibrarySyncer(
    account: AmperfyKit.Account,
    storage: PersistentStorage
  )
    -> LibrarySyncer { MOCK_LibrarySyncer() }
  func createArtworkDownloadDelegate()
    -> DownloadManagerDelegate { MOCK_DownloadManagerDelegate() }
  func extractArtworkInfoFromURL(urlString: String) -> ArtworkRemoteInfo? { nil }
  func cleanse(url: URL?) -> CleansedURL { CleansedURL(urlString: "") }
}

// MARK: - MOCK_NetworkMonitor

final class MOCK_NetworkMonitor: NetworkMonitorFacade {
  var connectionTypeChangedCB: ConnectionTypeChangedCallack? { get { nil } set {} }
  var isConnectedToNetwork: Bool { true }
  var isCellular: Bool { false }
  var isWifiOrEthernet: Bool { true }
}

// MARK: - MOCK_MusicPlayable

class MOCK_MusicPlayable: MusicPlayable {
  var thrownError: Error?

  var expectationDidStartPlaying: XCTestExpectation?
  var expectationErrorOccurred: XCTestExpectation?

  func didStartPlayingFromBeginning() {}
  func didStartPlaying() {
    expectationDidStartPlaying?.fulfill()
  }

  func didPause() {}
  func didStopPlaying() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}
  func didShuffleChange() {}
  func didRepeatChange() {}

  func errorOccurred(_ error: Error) {
    thrownError = error
    expectationErrorOccurred?.fulfill()
  }
}

// MARK: - MOCK_CoreDataManager

class MOCK_CoreDataManager: CoreDataManagable {
  var mock_persistentContainer: NSPersistentContainer

  init(persistentContainer: NSPersistentContainer) {
    self.mock_persistentContainer = persistentContainer
  }

  var persistentContainer: NSPersistentContainer {
    mock_persistentContainer
  }

  var context: NSManagedObjectContext {
    mock_persistentContainer.viewContext
  }
}

// MARK: - MusicPlayerTest

@MainActor
class MusicPlayerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var mockAlertDisplayer: MOCK_AlertDisplayable!
  var mockCoreDataManager: MOCK_CoreDataManager!
  var storage: PersistentStorage!
  var eventLogger: EventLogger!
  var userStatistics: UserStatistics!
  var songDownloader: MOCK_SongDownloader!
  var backendApi: MOCK_BackendApi!
  var networkMonitor: MOCK_NetworkMonitor!
  var backendPlayer: BackendAudioPlayer!
  var mockMusicPlayable: MOCK_MusicPlayable!
  var playerData: PlayerData!
  var testMusicPlayer: AmperfyKit.AudioPlayer!
  var testPlayer: AmperfyKit.PlayerFacade!
  var testQueueHandler: AmperfyKit.PlayQueueHandler!
  var mockAudioStreamingPlayer: MOCK_AudioStreamingPlayer!

  var songCached: Song!
  var songToDownload: Song!
  var playlistThreeCached: Playlist!
  var playlistAllCached: Playlist!
  let fillCount = 5

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    songDownloader = MOCK_SongDownloader()
    mockAudioStreamingPlayer = MOCK_AudioStreamingPlayer()
    mockAlertDisplayer = MOCK_AlertDisplayable()
    mockCoreDataManager = MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    storage = PersistentStorage(coreDataManager: mockCoreDataManager)
    eventLogger = EventLogger(storage: storage)
    userStatistics = library.getUserStatistics(appVersion: "")
    backendApi = MOCK_BackendApi()
    networkMonitor = MOCK_NetworkMonitor()
    backendPlayer = BackendAudioPlayer(
      createAudioStreamingPlayerCB: { self.mockAudioStreamingPlayer },
      audioSessionHandler: AudioSessionHandler(),
      eventLogger: eventLogger,
      getBackendApiCB: { accountInfo in self.backendApi },
      networkMonitor: networkMonitor,
      getPlayableDownloaderCB: { accountInfo in self.songDownloader },
      cacheProxy: library,
      userStatistics: userStatistics
    )
    mockMusicPlayable = MOCK_MusicPlayable()
    playerData = library.getPlayerData()
    testQueueHandler = PlayQueueHandler(playerData: playerData)
    testMusicPlayer = AudioPlayer(
      coreData: playerData,
      queueHandler: testQueueHandler,
      backendAudioPlayer: backendPlayer,
      settings: storage.settings,
      userStatistics: userStatistics
    )
    testPlayer = PlayerFacadeImpl(
      playerStatus: playerData,
      queueHandler: testQueueHandler,
      musicPlayer: testMusicPlayer,
      library: library,
      backendAudioPlayer: backendPlayer,
      userStatistics: userStatistics
    )
    testPlayer.addNotifier(notifier: mockMusicPlayable)

    guard let songCachedFetched = library.getSong(for: account, id: "36") else { XCTFail(); return }
    songCached = songCachedFetched
    guard let songToDownloadFetched = library.getSong(for: account, id: "3")
    else { XCTFail(); return }
    songToDownload = songToDownloadFetched
    guard let playlistCached = library.getPlaylist(
      for: account,
      id: cdHelper.seeder.playlists[1].id
    )
    else { XCTFail(); return }
    playlistThreeCached = playlistCached
    guard let playlistAllCachedFetched = library.getPlaylist(
      for: account,
      id: cdHelper.seeder.playlists[3].id
    )
    else { XCTFail(); return }
    playlistAllCached = playlistAllCachedFetched
  }

  override func tearDown() {}

  func getAccountForSong(atIndex: Int) -> Account {
    let accIndex = cdHelper.seeder.songs[atIndex].accountIndex
    let accSeed = cdHelper.seeder.accounts[accIndex]

    let acc = library.getAccount(info: AccountInfo(
      serverHash: accSeed.serverHash,
      userHash: accSeed.userHash,
      apiType: BackenApiType(rawValue: accSeed.apiType)!
    ))
    return acc
  }

  func prepareWithCachedPlaylist() {
    for song in playlistThreeCached.playables {
      testQueueHandler.appendContextQueue(playables: [song])
    }
  }

  func prepareWithAllSongsCached() {
    for song in playlistAllCached.playables {
      testQueueHandler.appendContextQueue(playables: [song])
    }
  }

  func markAsCached(playable: AbstractPlayable) {
    let relFilePath = URL(string: "testSong")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(
      data: Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!,
      to: absFilePath, accountInfo: account.info
    )
    playable.relFilePath = relFilePath
  }

  func prepareNoWaitingQueuePlaying() {
    playerData.removeAllItems()
    fillPlayerWithSomeSongsAndWaitingQueue()
    playerData.setUserQueuePlaying(false)
  }

  func prepareWithWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setUserQueuePlaying(true)
  }

  func fillPlayerWithSomeSongs() {
    for i in 0 ... fillCount - 1 {
      guard let song = library.getSong(
        for: getAccountForSong(atIndex: i),
        id: cdHelper.seeder.songs[i].id
      )
      else { XCTFail(); return }
      testPlayer.appendContextQueue(playables: [song])
    }
  }

  func fillPlayerWithSomeSongsAndWaitingQueue() {
    fillPlayerWithSomeSongs()
    for i in 0 ... 3 {
      guard let song = library.getSong(
        for: getAccountForSong(atIndex: i),
        id: cdHelper.seeder.songs[fillCount + i].id
      )
      else { XCTFail(); return }
      testPlayer.appendUserQueue(playables: [song])
    }
  }

  func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
    guard let song = library.getSong(
      for: getAccountForSong(atIndex: seedIndex),
      id: cdHelper.seeder.songs[seedIndex].id
    )
    else { XCTFail(); return }
    XCTAssertEqual(playerData.contextQueue.playables[playlistIndex].id, song.id)
  }

  func checkQueueItems(queue: [AbstractPlayable], seedIds: [Int]) {
    XCTAssertEqual(queue.count, seedIds.count)
    if queue.count == seedIds.count, !queue.isEmpty {
      for i in 0 ... queue.count - 1 {
        guard let song = library.getSong(
          for: getAccountForSong(atIndex: seedIds[i]),
          id: cdHelper.seeder.songs[seedIds[i]].id
        )
        else { XCTFail(); return }
        let queueId = queue[i].id
        let songId = song.id
        XCTAssertEqual(queueId, songId)
      }
    }
  }

  func checkCurrentlyPlaying(idToBe: Int?) {
    if let idToBe = idToBe {
      guard let song = library.getSong(
        for: getAccountForSong(atIndex: idToBe),
        id: cdHelper.seeder.songs[idToBe].id
      )
      else { XCTFail(); return }
      XCTAssertEqual(testQueueHandler.currentlyPlaying?.id, song.id)
    } else {
      XCTAssertNil(testQueueHandler.currentlyPlaying)
    }
  }

  func checkQueueInfoConsistency() {
    /// -------------------
    /// Prev Queue
    /// -------------------
    let prevQueueCount = testQueueHandler.prevQueueCount
    let prevQueueItemsAll = testQueueHandler.getAllPrevQueueItems()
    XCTAssertEqual(prevQueueCount, prevQueueItemsAll.count)
    for (index, item) in prevQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getPrevQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var prevRangItemsAll = testQueueHandler.getPrevQueueItems(from: 0, to: nil)
    XCTAssertEqual(prevRangItemsAll, prevQueueItemsAll)

    if prevQueueCount > 0 {
      prevRangItemsAll = testQueueHandler.getPrevQueueItems(from: 0, to: prevQueueCount - 1)
      XCTAssertEqual(prevRangItemsAll, prevQueueItemsAll)
    }
    if prevQueueCount > 1 {
      let prevRangeItemsBeforeEnd1 = testQueueHandler.getPrevQueueItems(
        from: 0,
        to: prevQueueCount - 2
      )
      XCTAssertEqual(prevRangeItemsBeforeEnd1.count, prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsBeforeEnd1, Array(prevQueueItemsAll[0 ... prevQueueCount - 2]))
      let prevRangeItemsOff1 = testQueueHandler.getPrevQueueItems(from: 1, to: prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsOff1.count, prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsOff1, Array(prevQueueItemsAll[1 ... prevQueueCount - 1]))
      XCTAssertEqual(prevRangeItemsOff1[0], prevQueueItemsAll[1])
    }
    if prevQueueCount > 2 {
      let prevRangeItemsMissingStartAndEnd = testQueueHandler.getPrevQueueItems(
        from: 1,
        to: prevQueueCount - 2
      )
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd.count, prevQueueCount - 2)
      XCTAssertEqual(
        prevRangeItemsMissingStartAndEnd,
        Array(prevQueueItemsAll[1 ... prevQueueCount - 2])
      )
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd[0], prevQueueItemsAll[1])
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd.last!, prevQueueItemsAll[prevQueueCount - 2])
    }
    /// -------------------
    /// User Queue
    /// -------------------
    let userQueueCount = testQueueHandler.userQueueCount
    let userQueueItemsAll = testQueueHandler.getAllUserQueueItems()
    XCTAssertEqual(userQueueCount, userQueueItemsAll.count)
    for (index, item) in userQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getUserQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var userRangItemsAll = testQueueHandler.getUserQueueItems(from: 0, to: nil)
    XCTAssertEqual(userRangItemsAll, userQueueItemsAll)

    if userQueueCount > 0 {
      userRangItemsAll = testQueueHandler.getUserQueueItems(from: 0, to: userQueueCount - 1)
      XCTAssertEqual(userRangItemsAll, userQueueItemsAll)
    }
    if userQueueCount > 1 {
      let userRangeItemsBeforeEnd1 = testQueueHandler.getUserQueueItems(
        from: 0,
        to: userQueueCount - 2
      )
      XCTAssertEqual(userRangeItemsBeforeEnd1.count, userQueueCount - 1)
      XCTAssertEqual(userRangeItemsBeforeEnd1, Array(userQueueItemsAll[0 ... userQueueCount - 2]))
      let userRangeItemsOff1 = testQueueHandler.getUserQueueItems(from: 1, to: userQueueCount - 1)
      XCTAssertEqual(userRangeItemsOff1.count, userQueueCount - 1)
      XCTAssertEqual(userRangeItemsOff1, Array(userQueueItemsAll[1 ... userQueueCount - 1]))
      XCTAssertEqual(userRangeItemsOff1[0], userQueueItemsAll[1])
    }
    if userQueueCount > 2 {
      let userRangeItemsMissingStartAndEnd = testQueueHandler.getUserQueueItems(
        from: 1,
        to: userQueueCount - 2
      )
      XCTAssertEqual(userRangeItemsMissingStartAndEnd.count, userQueueCount - 2)
      XCTAssertEqual(
        userRangeItemsMissingStartAndEnd,
        Array(userQueueItemsAll[1 ... userQueueCount - 2])
      )
      XCTAssertEqual(userRangeItemsMissingStartAndEnd[0], userQueueItemsAll[1])
      XCTAssertEqual(userRangeItemsMissingStartAndEnd.last!, userQueueItemsAll[userQueueCount - 2])
    }
    /// -------------------
    /// Next Queue
    /// -------------------
    let nextQueueCount = testQueueHandler.nextQueueCount
    let nextQueueItemsAll = testQueueHandler.getAllNextQueueItems()
    XCTAssertEqual(nextQueueCount, nextQueueItemsAll.count)
    for (index, item) in nextQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getNextQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var nextRangItemsAll = testQueueHandler.getNextQueueItems(from: 0, to: nil)
    XCTAssertEqual(nextRangItemsAll, nextQueueItemsAll)

    if nextQueueCount > 0 {
      nextRangItemsAll = testQueueHandler.getNextQueueItems(from: 0, to: nextQueueCount - 1)
      XCTAssertEqual(nextRangItemsAll, nextQueueItemsAll)
    }
    if nextQueueCount > 1 {
      let nextRangeItemsBeforeEnd1 = testQueueHandler.getNextQueueItems(
        from: 0,
        to: nextQueueCount - 2
      )
      XCTAssertEqual(nextRangeItemsBeforeEnd1.count, nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsBeforeEnd1, Array(nextQueueItemsAll[0 ... nextQueueCount - 2]))
      let nextRangeItemsOff1 = testQueueHandler.getNextQueueItems(from: 1, to: nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsOff1.count, nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsOff1, Array(nextQueueItemsAll[1 ... nextQueueCount - 1]))
      XCTAssertEqual(nextRangeItemsOff1[0], nextQueueItemsAll[1])
    }
    if nextQueueCount > 2 {
      let nextRangeItemsMissingStartAndEnd = testQueueHandler.getNextQueueItems(
        from: 1,
        to: nextQueueCount - 2
      )
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd.count, nextQueueCount - 2)
      XCTAssertEqual(
        nextRangeItemsMissingStartAndEnd,
        Array(nextQueueItemsAll[1 ... nextQueueCount - 2])
      )
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd[0], nextQueueItemsAll[1])
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd.last!, nextQueueItemsAll[nextQueueCount - 2])
    }
  }

  // -------------------------------------------------------------

  func testCreation() {
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertFalse(testPlayer.isShuffle)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.getAllNextQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.getAllUserQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.elapsedTime, 0.0)
    XCTAssertEqual(testPlayer.duration, 0.0)
    XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
    XCTAssertTrue(songDownloader.isNoDownloadRequested())
  }

  func testPlay_EmptyPlaylist() {
    testPlayer.play()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlay_OneCachedSongInPlayer_IsPlayingTrue() {
    testPlayer.appendContextQueue(playables: [songCached])
    testPlayer.play()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, songCached)
  }

  func testPlay_OneCachedSongInPlayer_NoDownloadRequest() {
    testPlayer.appendContextQueue(playables: [songCached])
    testPlayer.play()
    XCTAssertTrue(songDownloader.isNoDownloadRequested())
  }

  func testPlay_OneSongToDownload_IsPlayingFalse_UntilDownloadfinishes() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    testPlayer.appendContextQueue(playables: [songToDownload])
    testPlayer.play()
    XCTAssertFalse(testPlayer.isPlaying)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, songToDownload)
  }

  func testPlay_OneSongToDownload_CheckDownloadRequest() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    testPlayer.isAutoCachePlayedItems = true
    testPlayer.appendContextQueue(playables: [songToDownload])
    testPlayer.play()
    XCTAssertEqual(songDownloader.downloadables.count, 0)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertEqual(songDownloader.downloadables.count, 1)
    XCTAssertEqual(
      (songDownloader.downloadables.first! as! AbstractPlayable).asSong!,
      songToDownload
    )
  }

  func testPlaySong_Cached() {
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))
    XCTAssertEqual(testPlayer.currentlyPlaying, songCached)
  }

  func testContextName() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    XCTAssertEqual(testPlayer.contextName, "asdf")
  }

  func testContextName_changeContext() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    XCTAssertEqual(testPlayer.contextName, "asdf")
    testPlayer.play(context: PlayContext(name: "uio qwe", playables: [songCached]))
    XCTAssertEqual(testPlayer.contextName, "uio qwe")
  }

  func testContextName_insertContext() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    testPlayer.insertContextQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.contextName, "Mixed Context")
  }

  func testContextName_appendContext() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    testPlayer.appendContextQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.contextName, "Mixed Context")
  }

  func testContextName_insertUser() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    testPlayer.insertUserQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.contextName, "asdf")
  }

  func testContextName_appendUser() {
    testPlayer.play(context: PlayContext(name: "asdf", playables: [songCached]))
    testPlayer.appendUserQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.contextName, "asdf")
  }

  func testPlaySong_CheckPlaylistClear() {
    prepareWithCachedPlaylist()
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.getAllUserQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.getAllNextQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testPlayer.currentlyPlaying, songCached)
  }

  func testPlaySongInPlaylistAt_EmptyPlaylist() {
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 5))
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: -1))
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlaySongInPlaylistAt_Cached_FullPlaylist() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 3)
  }

  func testPlaySongInPlaylistAt_FetchSuccess_FullPlaylist() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 1))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 2)
  }

  func testPause_EmptyPlaylist() {
    testMusicPlayer.pause()
    XCTAssertFalse(testPlayer.isPlaying)
  }

  func testPause_CurrentlyPlaying() {
    testPlayer.appendContextQueue(playables: [songCached])
    testPlayer.play()
    testMusicPlayer.pause()
    XCTAssertFalse(testPlayer.isPlaying)
  }

  func testPause_CurrentlyPaused() {
    testPlayer.appendContextQueue(playables: [songCached])
    testMusicPlayer.pause()
    XCTAssertFalse(testPlayer.isPlaying)
  }

  func testPause_SongInMiddleOfPlaylist() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 3)
    testMusicPlayer.pause()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 3)
    testPlayer.play()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 3)
  }

  func testAddToPlaylist() {
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    testPlayer.appendContextQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    testPlayer.appendContextQueue(playables: [songToDownload])
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    testPlayer.appendContextQueue(playables: [songCached])
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    testPlayer.appendContextQueue(playables: [songToDownload])
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 3)
  }

  func testPlaylistClear_EmptyPlaylist() {
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlaylistClear_EmptyPlaylist_WaitingQueueHasEntries() {
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlaylistClear_EmptyPlaylist_WaitingQueueHasEntries2() {
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId1])
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlaylistClear_EmptyPlaylist_WaitingQueueHasEntries3() {
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.insertUserQueue(playables: [songId0])
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlaylistClear_EmptyPlaylist_WaitingQueueHasEntries4() {
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.insertUserQueue(playables: [songId0])
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.insertUserQueue(playables: [songId1])
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems()[0], songId1)
  }

  func testPlaylistClear_EmptyPlaylist_WaitingQueueHasEntries5() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId1])
    testPlayer.play()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 3.0)
    XCTAssertTrue(testPlayer.isPlaying)
    testPlayer.clearContextQueue()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlaylistClear_FilledPlaylist() {
    prepareWithCachedPlaylist()
    testPlayer.clearContextQueue()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlaylistClear_FilledPlaylist_WaitingQueuePlaying() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    prepareWithCachedPlaylist()
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId1])
    testPlayer.clearContextQueue()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlaylistClear_FilledPlaylist_WaitingQueuePlaying2() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    prepareWithCachedPlaylist()
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId1])
    testPlayer.playNext()
    testPlayer.clearContextQueue()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId0)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.playNext()

    testPlayer.clearContextQueue()
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.appendContextQueue(playables: [songId1, songId2, songId3])
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying2() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.playNext()

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1, songId2, songId3]))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying8() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1, songId2, songId3]))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlaySong_WaitingQueuePlaying8() {
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlaySong_WaitingQueuePlaying9() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying?.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.appendUserQueue(playables: [songId1])
    testPlayer.appendUserQueue(playables: [songId2])
    testPlayer.playNext()

    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId3]))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 3.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId3)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying3() {
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.appendUserQueue(playables: [songId1])
    testPlayer.appendUserQueue(playables: [songId2])
    testPlayer.playNext()

    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId3]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId3)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying4() {
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.playNext()

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying5() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    playerData.setCurrentIndex(1)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])
    testPlayer.playNext()

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1]))
    XCTAssertFalse(testPlayer.isPlaying)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying, songId1)
  }

  func testPlayMulitpleSongs_WaitingQueuePlaying6() {
    prepareWithCachedPlaylist()
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId0]))

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId1.id)
  }

  func testPlayMulitpleSongs_userQueueHasElements_notUserQueuePlaying() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId1.id)
  }

  func testPlayMulitpleSongs_userQueueHasElements_notUserQueuePlaying2() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(name: "", playables: [songId1, songId2, songId3]))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId1.id)
  }

  func testPlayMulitpleSongs_userQueueHasElements_notUserQueuePlaying3() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      index: 1,
      playables: [songId1, songId2, songId3]
    ))
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId2.id)
  }

  func testPlayMulitpleSongs_userQueueHasElements_notUserQueuePlaying4() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId4 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    guard let songId5 = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testPlayer.appendUserQueue(playables: [songId0, songId4, songId5])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      index: 2,
      playables: [songId1, songId2, songId3]
    ))
    XCTAssertFalse(testPlayer.isPlaying)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId3.id)
    XCTAssertEqual(testPlayer.getAllUserQueueItems()[0].id, songId4.id)
    XCTAssertEqual(testPlayer.getAllUserQueueItems()[1].id, songId5.id)
  }

  func testPlayMulitpleSongs_switchPlayerMode_toMusic() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId4 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    guard let songId5 = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testPlayer.appendContextQueue(playables: [songId0, songId4, songId5])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.insertPodcastQueue(playables: [songId1, songId2, songId3])
    testPlayer.setPlayerMode(.podcast)

    guard let songId7 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    guard let songId8 = library.getSong(for: account, id: cdHelper.seeder.songs[8].id)
    else { XCTFail(); return }
    guard let songId9 = library.getSong(for: account, id: cdHelper.seeder.songs[9].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      index: 1,
      playables: [songId7, songId8, songId9]
    ))
    XCTAssertEqual(testPlayer.playerMode, PlayerMode.music)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId8.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId7.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId9.id)

    testPlayer.setPlayerMode(.podcast)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId1.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId2.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[1].id, songId3.id)
  }

  func testPlayMulitpleSongs_switchPlayerMode_toMusic2() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId4 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    guard let songId5 = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testPlayer.appendContextQueue(playables: [songId0, songId4, songId5])
    playerData.setCurrentIndex(0)

    testPlayer.setPlayerMode(.podcast)
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.insertPodcastQueue(playables: [songId1, songId2, songId3])
    playerData.setCurrentIndex(1)

    guard let songId7 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    guard let songId8 = library.getSong(for: account, id: cdHelper.seeder.songs[8].id)
    else { XCTFail(); return }
    guard let songId9 = library.getSong(for: account, id: cdHelper.seeder.songs[9].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      type: .music,
      index: 2,
      playables: [songId7, songId8, songId9]
    ))
    XCTAssertEqual(testPlayer.playerMode, PlayerMode.music)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId9.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId7.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[1].id, songId8.id)

    testPlayer.setPlayerMode(.podcast)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId2.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId1.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId3.id)
  }

  func testPlayMulitpleSongs_switchPlayerMode_toPodcast() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId4 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    guard let songId5 = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testPlayer.appendContextQueue(playables: [songId0, songId4, songId5])

    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.insertPodcastQueue(playables: [songId1, songId2, songId3])

    guard let songId7 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    guard let songId8 = library.getSong(for: account, id: cdHelper.seeder.songs[8].id)
    else { XCTFail(); return }
    guard let songId9 = library.getSong(for: account, id: cdHelper.seeder.songs[9].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      type: .podcast,
      index: 1,
      playables: [songId7, songId8, songId9]
    ))
    XCTAssertEqual(testPlayer.playerMode, PlayerMode.podcast)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId8.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId7.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId9.id)

    testPlayer.setPlayerMode(.music)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 2)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId0.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId4.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[1].id, songId5.id)
  }

  func testPlayMulitpleSongs_switchPlayerMode_toPodcast2() {
    playerData.removeAllItems()
    playerData.setUserQueuePlaying(false)
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId4 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    guard let songId5 = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testPlayer.appendContextQueue(playables: [songId0, songId4, songId5])
    playerData.setCurrentIndex(1)

    testPlayer.setPlayerMode(.podcast)
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }
    guard let songId2 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let songId3 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    testPlayer.insertPodcastQueue(playables: [songId1, songId2, songId3])
    playerData.setCurrentIndex(0)

    guard let songId7 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    guard let songId8 = library.getSong(for: account, id: cdHelper.seeder.songs[8].id)
    else { XCTFail(); return }
    guard let songId9 = library.getSong(for: account, id: cdHelper.seeder.songs[9].id)
    else { XCTFail(); return }
    testPlayer.play(context: PlayContext(
      name: "",
      type: .podcast,
      index: 2,
      playables: [songId7, songId8, songId9]
    ))
    XCTAssertEqual(testPlayer.playerMode, PlayerMode.podcast)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 0)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId9.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId7.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[1].id, songId8.id)

    testPlayer.setPlayerMode(.music)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 1)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 1)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songId4.id)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems()[0].id, songId0.id)
    XCTAssertEqual(testPlayer.getAllNextQueueItems()[0].id, songId5.id)
  }

  func testPlay_ContextNameChanges() {
    playerData.removeAllItems()
    guard let songId0 = library.getSong(
      for: getAccountForSong(atIndex: 0),
      id: cdHelper.seeder.songs[0].id
    )
    else { XCTFail(); return }
    guard let songId1 = library.getSong(
      for: getAccountForSong(atIndex: 1),
      id: cdHelper.seeder.songs[1].id
    )
    else { XCTFail(); return }

    testPlayer.play(context: PlayContext(name: "Blub", playables: [songId0, songId1]))
    XCTAssertEqual(testPlayer.contextName, "Blub")
    testPlayer.setPlayerMode(.podcast)
    XCTAssertEqual(testPlayer.contextName, "Podcasts")
    testPlayer.appendContextQueue(playables: [songId0])
    XCTAssertEqual(testPlayer.contextName, "Podcasts")
    testPlayer.setPlayerMode(.music)
    XCTAssertEqual(testPlayer.contextName, "Mixed Context")

    testPlayer.play(context: PlayContext(name: "YYYY", playables: [songId0, songId1]))
    XCTAssertEqual(testPlayer.contextName, "YYYY")
    testPlayer.play(context: PlayContext(
      name: "GoGo Podcasts",
      type: .podcast,
      playables: [songId0, songId1]
    ))
    XCTAssertEqual(testPlayer.contextName, "Podcasts")
    testPlayer.setPlayerMode(.music)
    XCTAssertEqual(testPlayer.contextName, "YYYY")

    testPlayer.play(context: PlayContext(name: "BBBB", playables: [songId0, songId1]))
    XCTAssertEqual(testPlayer.contextName, "BBBB")
    testPlayer.appendPodcastQueue(playables: [songId0])
    XCTAssertEqual(testPlayer.contextName, "BBBB")
    testPlayer.setPlayerMode(.podcast)
    XCTAssertEqual(testPlayer.contextName, "Podcasts")
    testPlayer.insertPodcastQueue(playables: [songId0])
    testPlayer.setPlayerMode(.music)
    XCTAssertEqual(testPlayer.contextName, "BBBB")

    testPlayer.setPlayerMode(.music)
    testPlayer.insertContextQueue(playables: [songId0])
    XCTAssertEqual(testPlayer.contextName, "Mixed Context")
  }

  func testSeek_EmptyPlaylist() {
    testPlayer.seek(toSecond: 3.0)
    XCTAssertEqual(testPlayer.elapsedTime, 0.0)
  }

  func testSeek_FilledPlaylist() {
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))
    testPlayer.seek(toSecond: 3.0)
    backendPlayer
      .didStartPlaying(
        url: library.getFileURL(forPlayable: testPlayer.currentlyPlaying!)!
          .absoluteString
      )
    let elapsedTime = testPlayer.elapsedTime
    XCTAssertEqual(elapsedTime, 3.0)
  }

  func testPlayPreviousOrReplay_EmptyPlaylist() {
    testPlayer.playPreviousOrReplay()
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlayPreviousOrReplay_Previous() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    testPlayer.playPreviousOrReplay()
    XCTAssertEqual(playerData.currentIndex, 2)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 2)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 6)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.elapsedTime, 0.0)
  }

  func testPlayPreviousOrReplay_Replay() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    XCTAssertFalse(testPlayer.isStopInsteadOfPause)
    testPlayer.seek(toSecond: 10.0)

    backendPlayer
      .didStartPlaying(
        url: library.getFileURL(forPlayable: testPlayer.currentlyPlaying!)!
          .absoluteString
      )

    testPlayer.playPreviousOrReplay()
    XCTAssertTrue(testPlayer.isSkipAvailable)
    XCTAssertEqual(playerData.currentIndex, 3)
    XCTAssertEqual(testPlayer.getAllPrevQueueItems().count, 3)
    XCTAssertEqual(testPlayer.getAllUserQueueItems().count, 0)
    XCTAssertEqual(testPlayer.getAllNextQueueItems().count, 5)
    checkQueueInfoConsistency()
    XCTAssertEqual(testPlayer.elapsedTime, 0.0)
  }

  func testPlayPreviousOrReplay_Radio_Previous() {
    let radios = library.getRadios(for: account)
    XCTAssertEqual(radios.count, 4)
    testPlayer.play(context: PlayContext(name: "Radios", playables: radios))
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    testPlayer.seek(toSecond: 10.0)
    testPlayer.playPreviousOrReplay()
    XCTAssertEqual(playerData.currentIndex, 2)
  }

  func testPauseRadio() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "DidStartPlaying")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2

    let radios = library.getRadios(for: account)
    XCTAssertEqual(radios.count, 4)
    testPlayer.play(context: PlayContext(name: "Radios", playables: radios))
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isStopInsteadOfPause)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 3)
    testPlayer.pause()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertFalse(testPlayer.isSkipAvailable)
    XCTAssertEqual(playerData.currentIndex, 3)
  }

  func testRadioInvalidUrl() {
    let radios = library.getRadios(for: account)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "Normal Play")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    testPlayer.play(context: PlayContext(name: "Radios", playables: radios))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "Invalid URL")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)

    XCTAssertTrue(testPlayer.isStopInsteadOfPause)
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 1)
  }

  func testPlayPrevious_EmptyPlaylist() {
    testMusicPlayer.playPrevious()
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlayPrevious_Normal() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 2)
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 1)
  }

  func testPlayPrevious_AtStart() {
    prepareWithCachedPlaylist()
    testPlayer.play()
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 0)
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 0)
  }

  func testPlayPrevious_RepeatAll() {
    prepareWithCachedPlaylist()
    testPlayer.setRepeatMode(.all)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    testMusicPlayer.playPrevious()
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 8)
  }

  func testPlayPrevious_RepeatAll_OnlyOneSong() {
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))
    testPlayer.setRepeatMode(.all)
    testMusicPlayer.playPrevious()
    testMusicPlayer.playPrevious()
    XCTAssertEqual(playerData.currentIndex, 0)
  }

  func testPlayPrevious_StartPlayIfPaused() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    testMusicPlayer.pause()
    testMusicPlayer.playPrevious()
    XCTAssertTrue(testPlayer.isPlaying)
  }

  func testPlayPrevious_IsPlayingStaysTrue() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    testMusicPlayer.playPrevious()
    XCTAssertTrue(testPlayer.isPlaying)
  }

  func testPlayNext_EmptyPlaylist() {
    testPlayer.playNext()
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testPlayNext_Normal() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 4)
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 5)
  }

  func testPlayNext_AtStart() {
    prepareWithCachedPlaylist()
    testPlayer.play()
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 1)
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 2)
  }

  func testPlayNext_RepeatAll() {
    prepareWithCachedPlaylist()
    testPlayer.setRepeatMode(.all)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 7))
    testPlayer.playNext()
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 1)
  }

  func testPlayNext_RepeatAll_OnlyOneSong() {
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))
    testPlayer.setRepeatMode(.all)
    testPlayer.playNext()
    testPlayer.playNext()
    XCTAssertEqual(playerData.currentIndex, 0)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, songCached.id)
  }

  func testPlayNext_StartPlayIfPaused() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    testMusicPlayer.pause()
    testPlayer.playNext()
    XCTAssertFalse(testPlayer.isPlaying)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 3.0)
    XCTAssertTrue(testPlayer.isPlaying)
  }

  func testPlayNext_IsPlayingStaysTrue() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 2
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    testPlayer.playNext()
    XCTAssertFalse(testPlayer.isPlaying)
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
  }

  func testStop_EmptyPlaylist() {
    testPlayer.stop()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying, nil)
  }

  func testStop_Playing() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 6))
    testPlayer.stop()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistThreeCached.playables[0].id)
  }

  func testStop_AlreadyStopped() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 6))
    testPlayer.stop()
    testPlayer.stop()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(playerData.currentIndex, 0)
  }

  func testTogglePlay_EmptyPlaylist() {
    testPlayer.togglePlayPause()
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.togglePlayPause()
    XCTAssertFalse(testPlayer.isPlaying)
    testPlayer.togglePlayPause()
    XCTAssertFalse(testPlayer.isPlaying)
  }

  func testTogglePlay_AfterPlay() {
    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 6))
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    testPlayer.togglePlayPause()
    XCTAssertFalse(testPlayer.isPlaying)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    testPlayer.togglePlayPause()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)

    testPlayer.togglePlayPause()
    XCTAssertFalse(testPlayer.isPlaying)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "download is triggered")
    testPlayer.togglePlayPause()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
  }

  func testRemoveFromPlaylist_RemoveNotCurrentSong() {
    prepareWithCachedPlaylist()
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .prev, index: 2))
    XCTAssertEqual(playerData.currentIndex, 3)
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
    XCTAssertEqual(playerData.currentIndex, 3)
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    XCTAssertEqual(playerData.currentIndex, 3)
    testPlayer.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    XCTAssertEqual(playerData.currentIndex, 2)
  }

  func testPlayer_InsertNextInMainQueue_emptyMainQueue() {
    testPlayer.clearContextQueue()
    playerData.setCurrentIndex(0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [])
    testPlayer.insertContextQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [])
  }

  func testPlayer_InsertNextInMainQueue_emptyMainQueue_userQueuePlaing() {
    playerData.setCurrentIndex(0)
    testPlayer.insertUserQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [])
    checkQueueInfoConsistency()
    testPlayer.insertContextQueue(playables: [songToDownload])
    checkCurrentlyPlaying(idToBe: 4)
    XCTAssertEqual(playerData.currentIndex, -1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [])
    checkQueueInfoConsistency()
  }

  func testPlayer_InsertNextInMainQueue_WithWaitingQueuePlaying_nextEmpty() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertContextQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_InsertNextInMainQueue_noWaitingQueuePlaying_nextEmpty() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertContextQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_InsertNextInMainQueue_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertContextQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_InsertNextInMainQueue_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertContextQueue(playables: [songCached])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_AppendNextInMainQueue_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.appendContextQueue(playables: [songToDownload])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 0])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_AppendNextInMainQueue_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.appendContextQueue(playables: [songToDownload])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 0])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPrev_WithWaitingQueue_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(3)
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.setRepeatMode(.all)
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPrev_WithWaitingQueue_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    checkCurrentlyPlaying(idToBe: 5)
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.setRepeatMode(.all)
    checkCurrentlyPlaying(idToBe: 5)
    testMusicPlayer.playPrevious()
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayNext_WithWaitingQueue_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayNext_WithWaitingQueue_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    checkCurrentlyPlaying(idToBe: 5)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 7)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8])
    checkQueueInfoConsistency()
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    playerData.setCurrentIndex(4)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setRepeatMode(.all)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    playerData.setCurrentIndex(4)
    testPlayer.playNext()
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setRepeatMode(.single)
    testPlayer.playNext()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertFalse(playerData.isUserQueuePlaying)
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
  }

  func testPlayer_Play_indexValidation() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.play()
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_prev_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 1))
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 3))
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_prev_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 1))
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 4))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 3))
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_next_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(3)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 1))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 3))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_next_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(3)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 1))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 4))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 2))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_wait_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(3)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 1))
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 3))
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 2))
    checkCurrentlyPlaying(idToBe: 7)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
  }

  func testPlayer_PlayPlayIndex_wait_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(3)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(2)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 1))
    checkCurrentlyPlaying(idToBe: 7)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(4)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 2))
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 2))
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testPlayer.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    playerData.setCurrentIndex(0)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 8)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 6)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    playerData.setCurrentIndex(-1)
    testPlayer.play(playerIndex: PlayerIndex(queueType: .user, index: 1))
    checkCurrentlyPlaying(idToBe: 7)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8])
    checkQueueInfoConsistency()
  }

  func testSongFinishedPlaying_RepeatSingle() {
    prepareWithAllSongsCached()
    playerData.setCurrentIndex(1)
    testPlayer.play()
    testPlayer.setRepeatMode(.single)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)
  }

  func testSongFinishedPlaying_RepeatAll() {
    prepareWithAllSongsCached()
    playerData.setCurrentIndex(1)
    testPlayer.play()
    testPlayer.setRepeatMode(.all)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[3].id)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)
  }

  func testSongFinishedPlaying_RepeatAll_OneSong() {
    testPlayer.play(context: PlayContext(name: "", playables: [songCached]))

    testPlayer.setRepeatMode(.single)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)

    testPlayer.setRepeatMode(.all)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)

    mockMusicPlayable.expectationDidStartPlaying = expectation(description: "playback started")
    mockMusicPlayable.expectationDidStartPlaying!.expectedFulfillmentCount = 1
    backendPlayer.responder?.didItemFinishedPlaying()
    wait(for: [mockMusicPlayable.expectationDidStartPlaying!], timeout: 2.0)
    XCTAssertTrue(testPlayer.isPlaying)

    testPlayer.setRepeatMode(.off)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertFalse(testPlayer.isPlaying)
  }

  func testSongFinishedPlaying_RepeatOff() {
    prepareWithAllSongsCached()
    playerData.setCurrentIndex(1)
    testPlayer.play()
    testPlayer.setRepeatMode(.off)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[3].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertFalse(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)
  }

  func testSongFinishedPlaying_RepeatSingleOffMix() {
    prepareWithAllSongsCached()
    playerData.setCurrentIndex(1)
    testPlayer.play()
    testPlayer.setRepeatMode(.single)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    testPlayer.setRepeatMode(.off)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    testPlayer.setRepeatMode(.single)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    testPlayer.setRepeatMode(.off)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[3].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertFalse(testPlayer.isPlaying) // not playing
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)
  }

  func testSongFinishedPlaying_RepeatSingleAllMix() {
    prepareWithAllSongsCached()
    playerData.setCurrentIndex(1)
    testPlayer.play()
    testPlayer.setRepeatMode(.single)
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[1].id)

    testPlayer.setRepeatMode(.all)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[2].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[3].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)

    testPlayer.setRepeatMode(.single)
    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)

    backendPlayer.responder?.didItemFinishedPlaying()
    XCTAssertTrue(testPlayer.isPlaying)
    XCTAssertEqual(testPlayer.currentlyPlaying?.id, playlistAllCached.playables[0].id)
  }
}
