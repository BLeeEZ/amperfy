//
//  DownloadTest.swift
//  AmperfyKitTests
//
//  Created by butterfly-zebra on 13.10.26.
//  Copyright (c) 2026 butterfly-zebra. All rights reserved.
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
import CoreData
import XCTest

// MARK: - MOCK_DownloadURLProtocol

/// Answers a request with the response described by its own URL query, so the stub keeps no
/// shared state: `status`, `contentType` and `size` (the number of body bytes).
final class MOCK_DownloadURLProtocol: URLProtocol {
  static func url(statusCode: Int, contentType: String, size: Int) -> URL {
    var urlComp = URLComponents(string: "https://stub.amperfy.test/rest/download.view")!
    urlComp.queryItems = [
      URLQueryItem(name: "id", value: UUID().uuidString),
      URLQueryItem(name: "status", value: "\(statusCode)"),
      URLQueryItem(name: "contentType", value: contentType),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    return urlComp.url!
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url,
          let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let query = Dictionary(
      queryItems.map { ($0.name, $0.value ?? "") },
      uniquingKeysWith: { first, _ in first }
    )
    let body = Data(repeating: 0xFF, count: Int(query["size"] ?? "") ?? 0)
    guard let response = HTTPURLResponse(
      url: url,
      statusCode: Int(query["status"] ?? "") ?? 0,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": query["contentType"] ?? ""]
    ) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

// MARK: - DownloadTest

@MainActor
class DownloadTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var account2: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    account2 = library.getAccount(info: TestAccountInfo.create2())
  }

  override func tearDown() {}

  private func createUncachedSong(id: String, account: Account) -> Song {
    let song = library.createSong(account: account)
    song.id = id
    song.size = 1000
    song.album = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[0].id,
      isDetailFaultResolution: false
    )
    return song
  }

  @discardableResult
  private func createDownload(for song: Song, account: Account) -> Download {
    let download = library.createDownload(account: account, id: song.uniqueID)
    download.element = song
    return download
  }

  func testCompleteLibraryDownloadRequestsStaleDownloadsAgain() {
    _ = createUncachedSong(id: "noDownload", account: account)
    let pending = createUncachedSong(id: "pending", account: account)
    createDownload(for: pending, account: account)
    let finished = createUncachedSong(id: "finished", account: account)
    createDownload(for: finished, account: account).finishDate = Date()
    let failed = createUncachedSong(id: "failed", account: account)
    createDownload(for: failed, account: account).error = .fetchFailed
    let canceled = createUncachedSong(id: "canceled", account: account)
    createDownload(for: canceled, account: account).isCanceled = true
    let cached = createUncachedSong(id: "cached", account: account)
    cached.relFilePath = URL(string: "cached.mp3")
    createDownload(for: cached, account: account).finishDate = Date()
    library.saveContext()

    let songIds = Set(
      library.getSongsForCompleteLibraryDownload(for: account).map { $0.id }
    )
    XCTAssertTrue(songIds.contains("noDownload"))
    XCTAssertFalse(songIds.contains("pending"))
    XCTAssertTrue(songIds.contains("finished"))
    XCTAssertTrue(songIds.contains("failed"))
    XCTAssertTrue(songIds.contains("canceled"))
    XCTAssertFalse(songIds.contains("cached"))
  }

  func testClearFinishedDownloadsKeepsPendingDownloads() async {
    let pendingSong = createUncachedSong(id: "pending", account: account)
    let pending = createDownload(for: pendingSong, account: account)
    let finishedSong = createUncachedSong(id: "finished", account: account)
    let finished = createDownload(for: finishedSong, account: account)
    finished.finishDate = Date()
    let failedSong = createUncachedSong(id: "failed", account: account)
    let failed = createDownload(for: failedSong, account: account)
    failed.error = .fetchFailed
    let otherAccountSong = createUncachedSong(id: "otherAccount", account: account2)
    let otherAccountFinished = createDownload(for: otherAccountSong, account: account2)
    otherAccountFinished.finishDate = Date()
    library.saveContext()

    let requestManager = DownloadRequestManager(
      accountObjectId: account.managedObject.objectID,
      storage: AsyncCoreDataAccessWrapper(persistentContainer: cdHelper.persistentContainer),
      getDownloadDelegateCB: { MOCK_DownloadManagerDelegate() }
    )
    await requestManager.clearFinishedDownloads()

    XCTAssertNotNil(library.getDownload(account: account, id: pending.id))
    XCTAssertNil(library.getDownload(account: account, id: finished.id))
    XCTAssertNil(library.getDownload(account: account, id: failed.id))
    XCTAssertNotNil(library.getDownload(account: account2, id: otherAccountFinished.id))
  }

  func testDeleteCacheRemovesDownloadRecords() {
    let cached = createUncachedSong(id: "cached", account: account)
    cached.relFilePath = URL(string: "cached.mp3")
    let download = createDownload(for: cached, account: account)
    download.finishDate = Date()
    let otherAccountCached = createUncachedSong(id: "otherAccount", account: account2)
    otherAccountCached.relFilePath = URL(string: "otherAccount.mp3")
    let otherAccountDownload = createDownload(for: otherAccountCached, account: account2)
    otherAccountDownload.finishDate = Date()
    library.saveContext()

    library.deletePlayableCachePaths(for: account)
    library.saveContext()

    XCTAssertFalse(cached.isCached)
    XCTAssertNil(library.getDownload(account: account, id: download.id))
    XCTAssertNotNil(library.getDownload(account: account2, id: otherAccountDownload.id))
  }

  private func waitUntil(
    timeout: TimeInterval = 20,
    _ condition: @MainActor () async throws -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !(try await condition()) {
      guard Date() < deadline else {
        XCTFail("Timed out waiting for the download")
        return
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
  }

  private func readSessionDownloadState(
    downloadObjectID: NSManagedObjectID,
    songObjectID: NSManagedObjectID,
    storage: AsyncCoreDataAccessWrapper
  ) async throws
    -> SessionDownloadState {
    try await storage.performAndGet { asyncCompanion in
      let download = Download(
        managedObject: asyncCompanion.context.object(with: downloadObjectID) as! DownloadMO
      )
      let playable = AbstractPlayable(
        managedObject: asyncCompanion.context.object(with: songObjectID) as! AbstractPlayableMO
      )
      return SessionDownloadState(
        error: download.error,
        relFilePath: playable.relFilePath,
        contentTypeTranscoded: playable.contentTypeTranscoded,
        logMessages: asyncCompanion.library.getAllLogEntries().map { $0.message }
      )
    }
  }

  /// Downloads `url` through a real URLSessionDownloadTask that MOCK_DownloadURLProtocol answers,
  /// handled by the app's PlayableDownloadDelegate. Waits until the download failed (and its
  /// error was logged) or was cached.
  private func sessionDownload(url: URL) async throws -> SessionDownloadState {
    let song = createUncachedSong(id: UUID().uuidString, account: account)
    let download = createDownload(for: song, account: account)
    // object IDs are only permanent after saving
    library.saveContext()
    let downloadObjectID = download.managedObject.objectID
    let songObjectID = song.managedObject.objectID
    let asyncStorage = AsyncCoreDataAccessWrapper(persistentContainer: cdHelper.persistentContainer)
    let storage = PersistentStorage(
      coreDataManager: MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    )
    let eventLogger = EventLogger(storage: storage)
    let delegate = PlayableDownloadDelegate(
      backendApi: MOCK_BackendApi(),
      artworkExtractor: EmbeddedArtworkExtractor(),
      networkMonitor: MOCK_NetworkMonitor()
    )
    let requestManager = DownloadRequestManager(
      accountObjectId: account.managedObject.objectID,
      storage: asyncStorage,
      getDownloadDelegateCB: { delegate }
    )
    let downloadManager = DownloadManager(
      name: "TestDownloader",
      storage: asyncStorage,
      requestManager: requestManager,
      getDownloadDelegateCB: { delegate },
      eventLogger: eventLogger,
      settings: storage.settings,
      networkMonitor: MOCK_NetworkMonitor(),
      notificationHandler: EventNotificationHandler(),
      urlCleanser: MOCK_BackendApi(),
      limitCacheSize: false,
      isFailWithPopupError: false
    )
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MOCK_DownloadURLProtocol.self]
    let urlSession = URLSession(
      configuration: configuration,
      delegate: downloadManager,
      delegateQueue: nil
    )
    defer { urlSession.invalidateAndCancel() }
    downloadManager.initialize(
      urlSession: urlSession,
      isCheckForCachedNeeded: true,
      validationCB: nil
    )
    try await waitUntil { await downloadManager.urlSession != nil }

    let request = DownloadRequest(
      objectID: downloadObjectID,
      id: download.id,
      title: "song",
      info: DownloadElementInfo(objectId: songObjectID, type: .playable)
    )
    await downloadManager.fetch(downloadTaskInfo: DownloadTaskInfo(request: request, url: url))

    var state = try await readSessionDownloadState(
      downloadObjectID: downloadObjectID,
      songObjectID: songObjectID,
      storage: asyncStorage
    )
    try await waitUntil {
      state = try await readSessionDownloadState(
        downloadObjectID: downloadObjectID,
        songObjectID: songObjectID,
        storage: asyncStorage
      )
      let isFailedAndLogged = state.error != nil && !state.logMessages.isEmpty
      return isFailedAndLogged || state.relFilePath != nil
    }
    return state
  }

  /// Asserts that the downloaded file is in the cache and removes it again.
  private func assertCachedAndRemove(_ state: SessionDownloadState) {
    guard let relFilePath = state.relFilePath,
          let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)
    else {
      XCTFail("Download was not cached")
      return
    }
    XCTAssertTrue(FileManager.default.fileExists(atPath: absFilePath.path))
    try? CacheFileManager.shared.removeItem(at: absFilePath, accountInfo: account.info)
  }

  func testSessionDownloadWithErrorStatusIsNotCached() async throws {
    let state = try await sessionDownload(
      url: MOCK_DownloadURLProtocol.url(statusCode: 404, contentType: "audio/mpeg", size: 50_000)
    )
    XCTAssertEqual(state.error, .apiErrorResponse)
    XCTAssertNil(state.relFilePath)
    XCTAssertEqual(state.logMessages.count, 1)
    XCTAssertTrue(state.logMessages.first?.contains("status code: 404") ?? false)
  }

  func testSessionDownloadWithHtmlPageIsNotCached() async throws {
    let state = try await sessionDownload(
      url: MOCK_DownloadURLProtocol.url(
        statusCode: 200,
        contentType: "text/html; charset=utf-8",
        size: 30_000
      )
    )
    XCTAssertEqual(state.error, .apiErrorResponse)
    XCTAssertNil(state.relFilePath)
    XCTAssertEqual(state.logMessages.count, 1)
    XCTAssertTrue(state.logMessages.first?.contains("MIME type: text/html") ?? false)
  }

  func testSessionDownloadWithLargePlainTextIsCached() async throws {
    let state = try await sessionDownload(
      url: MOCK_DownloadURLProtocol.url(statusCode: 200, contentType: "text/plain", size: 5_000_000)
    )
    XCTAssertNil(state.error)
    XCTAssertEqual(state.contentTypeTranscoded, "text/plain")
    XCTAssertTrue(state.logMessages.isEmpty)
    assertCachedAndRemove(state)
  }

  func testSessionDownloadWithAudioIsCachedWithItsMimeType() async throws {
    let state = try await sessionDownload(
      url: MOCK_DownloadURLProtocol.url(statusCode: 200, contentType: "audio/mpeg", size: 50_000)
    )
    XCTAssertNil(state.error)
    XCTAssertEqual(state.contentTypeTranscoded, "audio/mpeg")
    XCTAssertTrue(state.logMessages.isEmpty)
    assertCachedAndRemove(state)
  }
}

// MARK: - SessionDownloadState

private struct SessionDownloadState: Sendable {
  let error: DownloadError?
  let relFilePath: URL?
  let contentTypeTranscoded: String?
  let logMessages: [String]
}
