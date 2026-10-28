//
//  SubsonicLibrarySyncerTest.swift
//  AmperfyKitTests
//
//  Created by Jerome Mohm on 28.10.26.
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

@MainActor
class SubsonicLibrarySyncerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var syncer: SubsonicLibrarySyncer!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create2())
    let storage = PersistentStorage(
      coreDataManager: MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    )
    let eventLogger = EventLogger(storage: storage)
    syncer = SubsonicLibrarySyncer(
      subsonicServerApi: SubsonicServerApi(
        performanceMonitor: MOCK_PerformanceMonitor(),
        eventLogger: eventLogger,
        settings: storage.settings
      ),
      account: account,
      networkMonitor: MOCK_NetworkMonitor(),
      performanceMonitor: MOCK_PerformanceMonitor(),
      storage: storage,
      eventLogger: eventLogger
    )
  }

  override func tearDown() {}

  /// Navidrome answers a deleted album with HTTP 200 and error 70. The album
  /// sync must mark the album deleted and hand the error to the caller.
  func testAlbumSyncMarksAlbumDeletedOnDataNotFoundAnswer() async throws {
    let album = library.createAlbum(account: account)
    album.id = "deletedAlbum"
    library.saveContext()
    let notFoundData = Data("""
    <subsonic-response xmlns="http://subsonic.org/restapi" status="failed" version="1.16.1" type="navidrome" openSubsonic="true">
      <error code="70" message="Album not found"></error>
    </subsonic-response>
    """.utf8)

    do {
      try await syncer.syncAlbumUncoalesced(album) {
        APIDataResponse(data: notFoundData, url: nil)
      }
      XCTFail("album sync did not throw")
    } catch {
      XCTAssertEqual((error as? ResponseError)?.asSubsonicError, .requestedDataNotFound)
    }
    // The sync marks the album in a background context
    cdHelper.persistentContainer.viewContext.refresh(album.managedObject, mergeChanges: false)
    XCTAssertEqual(album.remoteStatus, .deleted)
  }
}
