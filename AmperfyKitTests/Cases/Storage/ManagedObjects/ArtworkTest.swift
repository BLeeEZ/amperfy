//
//  ArtworkTest.swift
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
class ArtworkTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var testArtwork: Artwork!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    testArtwork = library.createArtwork()
  }

  override func tearDown() {}

  func testCreation() {
    let artwork = library.createArtwork()
    XCTAssertEqual(artwork.status.rawValue, ImageStatus.IsDefaultImage.rawValue)
    XCTAssertEqual(artwork.url, "")
    XCTAssertNil(artwork.image)
    XCTAssertEqual(artwork.owners.count, 0)
  }

  func testStatus() {
    testArtwork.status = ImageStatus.FetchError
    XCTAssertEqual(testArtwork.status, ImageStatus.FetchError)
    guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    artist1.managedObject.artwork = testArtwork.managedObject
    library.saveContext()
    guard let artistFetched = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artistFetched.artwork?.status, ImageStatus.FetchError)
  }

  func testUrl() {
    let testUrl = "www.test.de"
    testArtwork.url = testUrl
    XCTAssertEqual(testArtwork.url, testUrl)
    guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    artist1.managedObject.artwork = testArtwork.managedObject
    library.saveContext()
    guard let artistFetched = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(artistFetched.artwork?.url, testUrl)
  }

  func testImageWithCorrectStatus() {
    testArtwork.status = ImageStatus.CustomImage
    let testData = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!
    let testImg = UIImage(data: testData)
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(data: testData, to: absFilePath)
    testArtwork.relFilePath = relFilePath
    XCTAssertEqual(testArtwork.status, ImageStatus.CustomImage)
    XCTAssertEqual(testArtwork.image, testImg)
    try! CacheFileManager.shared.removeItem(at: absFilePath)
  }

  func testImageWithWrongStatus() {
    testArtwork.status = ImageStatus.NotChecked
    let testData = Data(base64Encoded: "Test", options: .ignoreUnknownCharacters)!
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(data: testData, to: absFilePath)
    testArtwork.relFilePath = relFilePath
    XCTAssertEqual(testArtwork.status, ImageStatus.NotChecked)
    XCTAssertNil(testArtwork.image)
    try! CacheFileManager.shared.removeItem(at: absFilePath)
  }

  func testOwners() {
    guard let artist1 = library.getArtist(id: cdHelper.seeder.artists[0].id)
    else { XCTFail(); return }
    guard let artist2 = library.getArtist(id: cdHelper.seeder.artists[1].id)
    else { XCTFail(); return }
    XCTAssertEqual(testArtwork.owners.count, 0)
    artist1.managedObject.artwork = testArtwork.managedObject
    XCTAssertEqual(testArtwork.owners.count, 1)
    artist2.managedObject.artwork = testArtwork.managedObject
    XCTAssertEqual(testArtwork.owners.count, 2)
  }
}
