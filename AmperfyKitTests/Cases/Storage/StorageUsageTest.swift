//
//  StorageUsageTest.swift
//  AmperfyKitTests
//
//  Created by David Masek on 22.08.26.
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
class StorageUsageTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
  }

  override func tearDown() {}

  func testCachedSongsFileInfosGroupedByAlbum() {
    let album1 = library.createAlbum(account: account)
    album1.name = "Album 1"
    let album2 = library.createAlbum(account: account)
    album2.name = "Album 2"

    let song1 = library.createSong(account: account)
    song1.id = "storageUsageSong1"
    song1.album = album1
    song1.relFilePath = URL(string: "songs/storageUsageSong1.mp3")

    let song2 = library.createSong(account: account)
    song2.id = "storageUsageSong2"
    song2.album = album1
    song2.relFilePath = URL(string: "songs/storageUsageSong2.mp3")

    let song3 = library.createSong(account: account)
    song3.id = "storageUsageSong3"
    song3.album = album2
    song3.relFilePath = URL(string: "songs/storageUsageSong3.mp3")

    // not cached -> must not be counted
    let song4 = library.createSong(account: account)
    song4.id = "storageUsageSong4"
    song4.album = album1

    // cached, but without album -> unknown album bucket
    let song5 = library.createSong(account: account)
    song5.id = "storageUsageSong5"
    song5.relFilePath = URL(string: "songs/storageUsageSong5.mp3")

    library.saveContext()

    let infos = library.getCachedSongsFileInfosGroupedByAlbum(for: account)

    guard let album1Info = infos.first(where: { $0.albumName == "Album 1" })
    else { XCTFail(); return }
    XCTAssertEqual(album1Info.songCount, 2)
    XCTAssertEqual(album1Info.relFilePaths.count, 2)

    guard let album2Info = infos.first(where: { $0.albumName == "Album 2" })
    else { XCTFail(); return }
    XCTAssertEqual(album2Info.songCount, 1)
    XCTAssertEqual(
      album2Info.relFilePaths.first?.path,
      "songs/storageUsageSong3.mp3"
    )

    guard let unknownAlbumInfo = infos.first(where: { $0.albumName == "Unknown Album" })
    else { XCTFail(); return }
    XCTAssertEqual(unknownAlbumInfo.songCount, 1)
  }

  func testGetDatabaseSizeInByte() throws {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
      .appendingPathComponent("StorageUsageTest-" + UUID().uuidString)
    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: tempDir) }

    let storeURL = tempDir.appendingPathComponent("Amperfy.sqlite")
    try Data(count: 100).write(to: storeURL)
    try Data(count: 10).write(to: tempDir.appendingPathComponent("Amperfy.sqlite-wal"))
    try Data(count: 20).write(to: tempDir.appendingPathComponent("Amperfy.sqlite-shm"))
    let externalDataDir = tempDir
      .appendingPathComponent(".Amperfy_SUPPORT")
      .appendingPathComponent("_EXTERNAL_DATA")
    try fileManager.createDirectory(at: externalDataDir, withIntermediateDirectories: true)
    try Data(count: 1_000).write(to: externalDataDir.appendingPathComponent("blob"))
    // unrelated file next to the store -> must not be counted
    try Data(count: 9_999).write(to: tempDir.appendingPathComponent("unrelated.txt"))

    XCTAssertEqual(PersistentStorage.getDatabaseSizeInByte(storeURL: storeURL), 1_130)
  }

  func testGetDatabaseSizeInByteOfMissingStore() {
    let missingStoreURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("StorageUsageTest-" + UUID().uuidString)
      .appendingPathComponent("Amperfy.sqlite")
    XCTAssertEqual(PersistentStorage.getDatabaseSizeInByte(storeURL: missingStoreURL), 0)
  }
}
