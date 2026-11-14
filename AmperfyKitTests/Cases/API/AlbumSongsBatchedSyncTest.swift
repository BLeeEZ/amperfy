//
//  AlbumSongsBatchedSyncTest.swift
//  AmperfyKitTests
//
//  Created by RaulitoRS97 on 10.11.26.
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
import CoreData
import XCTest

// MARK: - MOCK_AlbumNotAvailableError

struct MOCK_AlbumNotAvailableError: Error {}

// MARK: - AlbumSongsBatchedSyncTest

@MainActor
class AlbumSongsBatchedSyncTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var storage: PersistentStorage!
  var syncer: CommonLibrarySyncer!
  var fetchedAlbumIds = [String]()

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    storage = PersistentStorage(
      coreDataManager: MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    )
    syncer = CommonLibrarySyncer(
      account: account,
      networkMonitor: MOCK_NetworkMonitor(),
      performanceMonitor: MOCK_PerformanceMonitor(),
      storage: storage,
      eventLogger: EventLogger(storage: storage)
    )
  }

  override func tearDown() {}

  private func createUnsyncedAlbum(id: String) -> Album {
    let album = library.createAlbum(account: account)
    album.id = id
    album.name = id
    album.isSongsMetaDataSynced = false
    return album
  }

  /// Runs the batched sync over albums whose ids name the outcome of their fetch and write.
  private func syncAlbums(_ albums: [Album]) async {
    library.saveContext()
    await syncer.syncAlbumSongsBatched(
      targets: albums.map { AlbumSyncTarget(objectID: $0.managedObject.objectID, id: $0.id) },
      batchSize: 2,
      maxParallelFetches: 2,
      isCancelled: { false },
      fetch: { albumId in
        self.fetchedAlbumIds.append(albumId)
        switch albumId {
        case "fetchFails": throw MOCK_AlbumSyncError()
        case "fetchNotAvailable": throw MOCK_AlbumNotAvailableError()
        default: return albumId
        }
      },
      write: { asyncCompanion, albumObjectID, payload in
        switch payload {
        case "writeFails": throw MOCK_AlbumSyncError()
        case "writeNotAvailable": throw MOCK_AlbumNotAvailableError()
        default:
          let album = Album(
            managedObject: asyncCompanion.context.object(with: albumObjectID) as! AlbumMO
          )
          album.isSongsMetaDataSynced = true
        }
      },
      classifyNotAvailable: { $0 is MOCK_AlbumNotAvailableError }
    )
    cdHelper.persistentContainer.viewContext.refreshAllObjects()
  }

  func testWrittenAlbumIsSynced() async {
    let album = createUnsyncedAlbum(id: "written")
    await syncAlbums([album])
    XCTAssertTrue(album.isSongsMetaDataSynced)
    XCTAssertEqual(album.remoteStatus, .available)
  }

  func testAlbumWithFailedFetchStaysUnsynced() async {
    let album = createUnsyncedAlbum(id: "fetchFails")
    await syncAlbums([album])
    XCTAssertFalse(album.isSongsMetaDataSynced)
    XCTAssertEqual(album.remoteStatus, .available)
  }

  func testAlbumWithFailedWriteStaysUnsynced() async {
    let album = createUnsyncedAlbum(id: "writeFails")
    await syncAlbums([album])
    XCTAssertFalse(album.isSongsMetaDataSynced)
    XCTAssertEqual(album.remoteStatus, .available)
  }

  func testAlbumNotAvailableOnFetchIsMarkedDeleted() async {
    let album = createUnsyncedAlbum(id: "fetchNotAvailable")
    await syncAlbums([album])
    XCTAssertEqual(album.remoteStatus, .deleted)
  }

  func testAlbumNotAvailableOnWriteIsMarkedDeleted() async {
    let album = createUnsyncedAlbum(id: "writeNotAvailable")
    await syncAlbums([album])
    XCTAssertEqual(album.remoteStatus, .deleted)
  }

  func testFailedAlbumsDoNotAffectOthersInTheSameBatch() async {
    let albums = ["written", "fetchFails", "writeFails", "fetchNotAvailable", "writeNotAvailable"]
      .map { createUnsyncedAlbum(id: $0) }
    await syncAlbums(albums)
    XCTAssertEqual(albums.map(\.isSongsMetaDataSynced), [true, false, false, false, false])
    XCTAssertEqual(
      albums.map(\.remoteStatus),
      [.available, .available, .available, .deleted, .deleted]
    )
  }

  func testAlbumsLeftUnsyncedAreFoundAmongTheSyncedOnes() async throws {
    let albums = ["written", "fetchFails", "writeFails", "fetchNotAvailable"]
      .map { createUnsyncedAlbum(id: $0) }
    await syncAlbums(albums)
    let unsyncedIDs = try library
      .getAlbumObjectIDsWithoutSyncedSongs(among: albums.map(\.managedObject.objectID))
    XCTAssertEqual(unsyncedIDs, Set([albums[1], albums[2]].map(\.managedObject.objectID)))
  }

  func testAlbumSyncedMeanwhileIsNotFetchedAgain() async {
    let syncedMeanwhile = createUnsyncedAlbum(id: "syncedMeanwhile")
    let album = createUnsyncedAlbum(id: "written")
    // Synced by another caller after the targets were chosen
    syncedMeanwhile.isSongsMetaDataSynced = true
    await syncAlbums([syncedMeanwhile, album])
    XCTAssertEqual(fetchedAlbumIds, ["written"])
    XCTAssertTrue(syncedMeanwhile.isSongsMetaDataSynced)
    XCTAssertTrue(album.isSongsMetaDataSynced)
  }

  func testExcludedAlbumsAreNotFetchedForTheNextSync() {
    let albums = ["first", "excluded", "last"].map { createUnsyncedAlbum(id: $0) }
    library.saveContext()
    let fetchedIDs = Set(
      library.getAlbumWithoutSyncedSongs(
        fetchLimit: 1000,
        excluding: [albums[1].managedObject.objectID]
      ).map(\.id)
    )
    XCTAssertTrue(fetchedIDs.contains("first"))
    XCTAssertFalse(fetchedIDs.contains("excluded"))
    XCTAssertTrue(fetchedIDs.contains("last"))
  }
}
