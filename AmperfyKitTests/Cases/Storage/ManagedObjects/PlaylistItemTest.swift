//
//  PlaylistItemTest.swift
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
class PlaylistItemTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
  }

  override func tearDown() {}

  func testCreation() {
    guard let song1 = library.getSong(id: cdHelper.seeder.songs[0].id) else { XCTFail(); return }
    let item = library.createPlaylistItem(playable: song1)
    XCTAssertEqual(item.order, 0)

    XCTAssertEqual(item.playable.id, song1.id)
    guard let playlist = library.getPlaylist(id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    let itemOrder = playlist.playables.count
    item.playlist = playlist
    XCTAssertEqual(item.playlist.id, playlist.id)
    item.order = itemOrder
    XCTAssertEqual(item.order, itemOrder)

    guard let playlistFetched = library.getPlaylist(id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    XCTAssertEqual(playlistFetched.items[itemOrder].playable.id, song1.id)
    XCTAssertEqual(playlistFetched.items[itemOrder].playlist.id, playlistFetched.id)
    XCTAssertEqual(playlistFetched.items[itemOrder].order, itemOrder)
  }

  func testOrphanDetectionDeletedPlaylist() {
    guard let playlist = library.getPlaylist(id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    let playlistItemCount = playlist.songCount
    XCTAssertGreaterThan(playlistItemCount, 0)
    var orphans = library.getPlaylistItemOrphans()
    XCTAssertEqual(orphans.count, 0)

    playlist.managedObject.managedObjectContext?.delete(playlist.managedObject)
    orphans = library.getPlaylistItemOrphans()
    // Delete Rule should delete the orphans
    XCTAssertEqual(orphans.count, 0)
  }

  func testOrphanDetectionDeletedSong() {
    guard let playlist = library.getPlaylist(id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    let playlistItemCount = playlist.songCount
    XCTAssertGreaterThan(playlistItemCount, 0)
    var orphans = library.getPlaylistItemOrphans()
    XCTAssertEqual(orphans.count, 0)

    playlist.managedObject.managedObjectContext?.delete(playlist.playables[0].playableManagedObject)
    orphans = library.getPlaylistItemOrphans()
    // Delete Rule should delete the orphans
    XCTAssertEqual(orphans.count, 0)
  }
}
