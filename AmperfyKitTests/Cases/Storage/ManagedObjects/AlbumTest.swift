//
//  AlbumTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 31.12.19.
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

@testable import AmperfyKit
import XCTest

@MainActor
class AlbumTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var testAlbum: Album!
  let testId = "23489"

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    testAlbum = library.createAlbum(account: account)
    testAlbum.id = testId
  }

  override func tearDown() {}

  func testCreation() {
    let album = library.createAlbum(account: account)
    XCTAssertEqual(album.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.id, "")
    XCTAssertEqual(album.identifier, "Unknown Album")
    XCTAssertEqual(album.name, "Unknown Album")
    XCTAssertEqual(album.year, 0)
    XCTAssertEqual(album.artist, nil)
    XCTAssertEqual(album.songs.count, 0)
    XCTAssertEqual(album.songCount, 0)
    XCTAssertNil(album.artwork)
    XCTAssertNil(
      album.imagePath(setting: .serverArtworkOnly)
    )
    XCTAssertEqual(
      album.getDefaultArtworkType(), .album
    )
    XCTAssertFalse(album.playables.hasCachedItems)
    XCTAssertFalse(album.isOrphaned)
  }

  func testArtist() {
    guard let artist = library.getArtist(for: account, id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    testAlbum.artist = artist
    XCTAssertEqual(testAlbum.artist!.id, artist.id)
    library.saveContext()
    guard let albumFetched = library.getAlbum(
      for: account,
      id: testId,
      isDetailFaultResolution: true
    )
    else { XCTFail(); return }
    XCTAssertEqual(albumFetched.artist!.id, artist.id)
  }

  func testTitle() {
    let testTitle = "Alright"
    testAlbum.name = testTitle
    XCTAssertEqual(testAlbum.name, testTitle)
    XCTAssertEqual(testAlbum.identifier, testTitle)
    library.saveContext()
    guard let albumFetched = library.getAlbum(
      for: account,
      id: testId,
      isDetailFaultResolution: true
    )
    else { XCTFail(); return }
    XCTAssertEqual(albumFetched.name, testTitle)
    XCTAssertEqual(albumFetched.identifier, testTitle)
  }

  func testYear() {
    let testYear = 2001
    testAlbum.year = testYear
    XCTAssertEqual(testAlbum.year, testYear)
    library.saveContext()
    guard let albumFetched = library.getAlbum(
      for: account,
      id: testId,
      isDetailFaultResolution: true
    )
    else { XCTFail(); return }
    XCTAssertEqual(albumFetched.year, testYear)
  }

  func testArtworkAndImage() {
    let testData = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .album).pngData()!
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(
      data: testData,
      to: absFilePath,
      accountInfo: account.info
    )
    testAlbum.artwork = library.createArtwork(account: account)
    testAlbum.artwork?.relFilePath = relFilePath
    testAlbum.artwork?.status = .CustomImage
    XCTAssertNotNil(testAlbum.artwork?.imagePath)
    library.saveContext()
    guard let albumFetched = library.getAlbum(
      for: account,
      id: testId,
      isDetailFaultResolution: true
    )
    else { XCTFail(); return }
    XCTAssertNotNil(albumFetched.artwork?.imagePath)
    try! CacheFileManager.shared.removeItem(at: absFilePath, accountInfo: account.info)
  }

  func testSongs() {
    guard let album3Items = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[0].id,
      isDetailFaultResolution: true
    ) else { XCTFail(); return }
    XCTAssertEqual(album3Items.songs.count, 3)
    XCTAssertEqual(album3Items.songCount, 3)
    guard let album2Items = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[2].id,
      isDetailFaultResolution: true
    ) else { XCTFail(); return }
    XCTAssertEqual(album2Items.songs.count, 2)
    XCTAssertEqual(album2Items.songCount, 2)
  }

  func testHasCachedSongs() {
    guard let albumNoCached = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[0].id,
      isDetailFaultResolution: true
    ) else { XCTFail(); return }
    XCTAssertFalse(albumNoCached.playables.hasCachedItems)
    guard let albumTwoCached = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[2].id,
      isDetailFaultResolution: true
    ) else { XCTFail(); return }
    XCTAssertTrue(albumTwoCached.playables.hasCachedItems)
  }

  func testIsOrphaned() {
    testAlbum.name = "blub"
    XCTAssertFalse(testAlbum.isOrphaned)
    testAlbum.name = "Unknown Album"
    XCTAssertFalse(testAlbum.isOrphaned)
    testAlbum.name = "Orphaned"
    XCTAssertFalse(testAlbum.isOrphaned)
    testAlbum.name = "Unknown (Orphaned)"
    XCTAssertTrue(testAlbum.isOrphaned)
    testAlbum.name = "blub"
    XCTAssertFalse(testAlbum.isOrphaned)
  }
}
