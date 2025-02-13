//
//  HelperTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 30.12.19.
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
class HelperTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
  }

  override func tearDown() {}

  func testSeeder() {
    XCTAssertEqual(library.getArtists().count, cdHelper.seeder.artists.count)
    XCTAssertEqual(library.getAlbums().count, cdHelper.seeder.albums.count)
    XCTAssertEqual(library.getSongs().count, cdHelper.seeder.songs.count)
    XCTAssertEqual(library.getPlaylists().count, cdHelper.seeder.playlists.count)
  }
}
