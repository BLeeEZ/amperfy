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
    XCTAssertEqual(library.getAllAccounts().count, cdHelper.seeder.accounts.count)
    XCTAssertEqual(library.getAllArtists().count, cdHelper.seeder.artists.count)
    XCTAssertEqual(library.getAllAlbums().count, cdHelper.seeder.albums.count)
    XCTAssertEqual(library.getAllSongs().count, cdHelper.seeder.songs.count)
    XCTAssertEqual(
      library.getAllPlaylists(areSystemPlaylistsIncluded: false).count,
      cdHelper.seeder.playlists.count
    )
    let account = library.getAccount(info: TestAccountInfo.create1())
    XCTAssertEqual(account.managedObject.playlists?.count, 4)
    let account1PlaylistItemCount = cdHelper.seeder.playlists.filter { $0.accountIndex == 0 }
      .reduce(0) { $0 + $1.songIds.count }
    XCTAssertEqual(account.managedObject.playlistItems?.count, account1PlaylistItemCount)
    let account1EntityCount = cdHelper.seeder.artists.filter { $0.accountIndex == 0 }
      .count + cdHelper.seeder.albums
      .filter { $0.accountIndex == 0 }.count + cdHelper.seeder.songs
      .filter { $0.accountIndex == 0 }
      .count + cdHelper.seeder.radios.filter { $0.accountIndex == 0 }.count
    XCTAssertEqual(
      account.managedObject.entities?.count,
      account1EntityCount
    )

    XCTAssertEqual(library.getArtists(for: account).count, 3)
    XCTAssertEqual(library.getAlbums(for: account).count, 4)
    XCTAssertEqual(library.getSongs(for: account).count, 16)
    XCTAssertEqual(library.getPlaylists(for: account).count, 4)
    XCTAssertEqual(library.getRadios(for: account).count, 4)
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    XCTAssertEqual(library.getArtists(for: account2).count, 2)
    XCTAssertEqual(library.getAlbums(for: account2).count, 2)
    XCTAssertEqual(library.getSongs(for: account2).count, 4)
    XCTAssertEqual(library.getPlaylists(for: account2).count, 2)
    XCTAssertEqual(library.getRadios(for: account2).count, 2)
  }
}
