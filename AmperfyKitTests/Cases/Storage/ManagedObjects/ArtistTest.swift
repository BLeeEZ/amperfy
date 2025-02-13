//
//  ArtistTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.01.20.
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
import XCTest

@MainActor
class ArtistTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var testArtist: Artist!
  let testId = "10089"

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    testArtist = library.createArtist()
    testArtist.id = testId
  }

  override func tearDown() {}

  func testCreation() {
    let artist = library.createArtist()
    XCTAssertEqual(artist.id, "")
    XCTAssertEqual(artist.identifier, "Unknown Artist")
    XCTAssertEqual(artist.name, "Unknown Artist")
    XCTAssertEqual(artist.songs.count, 0)
    XCTAssertEqual(artist.songCount, 0)
    XCTAssertFalse(artist.playables.hasCachedItems)
    XCTAssertEqual(artist.albums.count, 0)
    XCTAssertEqual(artist.albumCount, 0)
    XCTAssertNil(artist.artwork)
    XCTAssertEqual(
      artist.image(theme: .blue, setting: .serverArtworkOnly),
      UIImage.getGeneratedArtwork(theme: .blue, artworkType: .artist)
    )
  }

  func testName() {
    let testTitle = "Alright"
    testArtist.name = testTitle
    XCTAssertEqual(testArtist.name, testTitle)
    XCTAssertEqual(testArtist.identifier, testTitle)
    library.saveContext()
    guard let artistFetched = library.getArtist(id: testId) else { XCTFail(); return }
    XCTAssertEqual(artistFetched.name, testTitle)
    XCTAssertEqual(artistFetched.identifier, testTitle)
  }

  func testSongs() {
    guard let artist3Items = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist3Items.songs.count, 3)
    XCTAssertEqual(artist3Items.songCount, 3)
    guard let artist2Items = library.getArtist(id: cdHelper.seeder.artists[1].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist2Items.songs.count, 2)
    XCTAssertEqual(artist2Items.songCount, 2)
  }

  func testHasCachedSongs() {
    guard let artistNoCached = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertFalse(artistNoCached.playables.hasCachedItems)
    guard let artistTwoCached = library.getArtist(id: cdHelper.seeder.artists[2].id)
    else { XCTFail(); return }
    XCTAssertTrue(artistTwoCached.playables.hasCachedItems)
  }

  func testAlbums() {
    guard let artist1Items = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist1Items.albums.count, 1)
    XCTAssertEqual(artist1Items.albumCount, 1)
    guard let artist2Items = library.getArtist(id: cdHelper.seeder.artists[2].id)
    else { XCTFail(); return }
    XCTAssertEqual(artist2Items.albums.count, 2)
    XCTAssertEqual(artist2Items.albumCount, 2)
  }

  func testArtworkAndImage() {
    let testData = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .artist).pngData()!
    let testImg = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .artist)
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(data: testData, to: absFilePath)
    testArtist.artwork = library.createArtwork()
    testArtist.artwork?.relFilePath = relFilePath
    XCTAssertNil(testArtist.artwork?.image)
    XCTAssertEqual(testArtist.image(theme: .blue, setting: .serverArtworkOnly), testImg)
    library.saveContext()
    guard let artistFetched = library.getArtist(id: testId) else { XCTFail(); return }
    XCTAssertNil(artistFetched.artwork?.image)
    XCTAssertEqual(artistFetched.image(theme: .blue, setting: .serverArtworkOnly), testImg)
    try! CacheFileManager.shared.removeItem(at: absFilePath)
  }
}
