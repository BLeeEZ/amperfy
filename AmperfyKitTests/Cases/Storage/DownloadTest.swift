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
import XCTest

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
}
