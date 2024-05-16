//
//  SongTest.swift
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

import XCTest
@testable import AmperfyKit

class SongTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testSong: Song!
    let testId = "2345"

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testSong = library.createSong()
        testSong.id = testId
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let song = library.createSong()
        XCTAssertEqual(song.id, "")
        XCTAssertNil(song.artwork)
        XCTAssertEqual(song.title, "Unknown Title")
        XCTAssertEqual(song.track, 0)
        XCTAssertEqual(song.url, nil)
        XCTAssertEqual(song.album, nil)
        XCTAssertEqual(song.artist, nil)
        XCTAssertEqual(song.displayString, "Unknown Artist - Unknown Title")
        XCTAssertEqual(song.identifier, "Unknown Title")
        XCTAssertEqual(song.image(setting: .serverArtworkOnly), UIImage.songArtwork)
        XCTAssertFalse(song.isCached)
    }
    
    func testArtist() {
        guard let artist = library.getArtist(id: cdHelper.seeder.artists[0].id) else { XCTFail(); return }
        testSong.artist = artist
        XCTAssertEqual(testSong.artist!.id, artist.id)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.artist!.id, artist.id)
    }
    
    func testAlbum() {
        guard let album = library.getAlbum(id: cdHelper.seeder.albums[0].id) else { XCTFail(); return }
        testSong.album = album
        XCTAssertEqual(testSong.album!.id, album.id)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.album!.id, album.id)
    }
    
    func testTitle() {
        let testTitle = "Alright"
        testSong.title = testTitle
        XCTAssertEqual(testSong.title, testTitle)
        XCTAssertEqual(testSong.displayString, "Unknown Artist - " + testTitle)
        XCTAssertEqual(testSong.identifier, testTitle)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.title, testTitle)
        XCTAssertEqual(songFetched.displayString, "Unknown Artist - " + testTitle)
        XCTAssertEqual(songFetched.identifier, testTitle)
    }
    
    func testTrack() {
        let testTrack = 13
        testSong.track = testTrack
        XCTAssertEqual(testSong.track, testTrack)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.track, testTrack)
    }
    
    func testUrl() {
        let testUrl = "www.blub.de"
        testSong.url = testUrl
        XCTAssertEqual(testSong.url, testUrl)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertEqual(songFetched.url, testUrl)
    }
    
    func testArtworkAndImage() {
        let testData = UIImage.songArtwork.pngData()!
        let testImg = UIImage.songArtwork
        let relFilePath = URL(string: "testArtwork")!
        let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
        try! CacheFileManager.shared.writeDataExcludedFromBackup(data: testData, to: absFilePath)
        testSong.artwork = library.createArtwork()
        testSong.artwork?.relFilePath = relFilePath
        XCTAssertNil(testSong.artwork?.image)
        XCTAssertEqual(testSong.image(setting: .serverArtworkOnly), testImg)
        library.saveContext()
        guard let songFetched = library.getSong(id: testId) else { XCTFail(); return }
        XCTAssertNil(songFetched.artwork?.image)
        XCTAssertEqual(songFetched.image(setting: .serverArtworkOnly), testImg)
        try! CacheFileManager.shared.removeItem(at: absFilePath)
    }
    
    func testRating() {
        testSong.rating = -1
        XCTAssertEqual(testSong.rating, 0)
        testSong.rating = 5
        XCTAssertEqual(testSong.rating, 5)
        testSong.rating = 1
        XCTAssertEqual(testSong.rating, 1)
        testSong.rating = 6
        XCTAssertEqual(testSong.rating, 1)
        testSong.rating = 0
        XCTAssertEqual(testSong.rating, 0)
        testSong.rating = 2
        XCTAssertEqual(testSong.rating, 2)
        testSong.rating = -500
        XCTAssertEqual(testSong.rating, 2)
        testSong.rating = 500
        XCTAssertEqual(testSong.rating, 2)
    }

}
