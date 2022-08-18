//
//  PlayableFileTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 02.01.20.
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

import XCTest
@testable import AmperfyKit

class PlayableFileTest: XCTestCase {
    
    var cdHelper: CoreDataHelper!
    var library: LibraryStorage!
    var testPlayableFile: PlayableFile!

    override func setUp() {
        cdHelper = CoreDataHelper()
        library = cdHelper.createSeededStorage()
        testPlayableFile = library.createPlayableFile()
    }

    override func tearDown() {
    }
    
    func testCreation() {
        let playableFile = library.createPlayableFile()
        XCTAssertEqual(playableFile.info, nil)
        XCTAssertEqual(playableFile.data, nil)
    }
    
    func testProperties() {
        let songId = cdHelper.seeder.songs[0].id
        let testData = UIImage.songArtwork.pngData()!
        guard let song = library.getSong(id: songId) else { XCTFail(); return }
        testPlayableFile.info = song
        testPlayableFile.data = testData
        XCTAssertEqual(testPlayableFile.info?.id, songId)
        XCTAssertEqual(testPlayableFile.data, testData)
        library.saveContext()
        guard let songFetched = library.getSong(id: songId) else { XCTFail(); return }
        guard let songFileFetched = library.getFile(forPlayable: songFetched) else { XCTFail(); return }
        XCTAssertEqual(songFileFetched.info?.id, songId)
        XCTAssertEqual(songFileFetched.data, testData)
    }

}
