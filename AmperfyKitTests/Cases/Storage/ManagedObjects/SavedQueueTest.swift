//
//  SavedQueueTest.swift
//  AmperfyKitTests
//
//  Created by Amperfy Contributors on 08.06.26.
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
class SavedQueueTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var songA: Song!
  var songB: Song!
  var songC: Song!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    songA = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    songB = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)!
    songC = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)!
  }

  override func tearDown() {}

  @MainActor
  func testSavedQueuePlaylistsAreExcludedFromLibrary() throws {
    let playlistCountBefore = library.getPlaylists(for: account).count
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [songA, songB].map { $0 as AbstractPlayable })
    library.saveContext()
    XCTAssertEqual(library.getPlaylists(for: account).count, playlistCountBefore)
  }

  @MainActor
  func testSongCountIsDerivedFromPlaylists() throws {
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [songA, songB].map { $0 as AbstractPlayable })
    saved.userQueuePlaylist.append(playables: [songC].map { $0 as AbstractPlayable })
    XCTAssertEqual(saved.songCount, 3)
  }

  @MainActor
  func testPlayablesConcatenatesContextThenUserQueue() throws {
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [songA].map { $0 as AbstractPlayable })
    saved.userQueuePlaylist.append(playables: [songB].map { $0 as AbstractPlayable })
    XCTAssertEqual(saved.playables.map { $0.id }, [songA.id, songB.id])
  }

  @MainActor
  func testDeletingSongPrunesItFromSavedQueue() throws {
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [songA, songB].map { $0 as AbstractPlayable })
    library.saveContext()
    // No deleteSong API exists; delete the MO directly (see Global Constraints).
    cdHelper.persistentContainer.viewContext.delete(songA.playableManagedObject)
    library.saveContext()
    XCTAssertEqual(saved.contextPlaylist.playables.map { $0.id }, [songB.id])
  }

  @MainActor
  func testContainerIdentifierRoundTrip() throws {
    let saved = library.createSavedQueue()
    saved.name = "Road Trip"
    library.saveContext()
    let resolved = library.getContainer(identifier: saved.containerIdentifier)
    XCTAssertEqual(resolved?.name, "Road Trip")
    XCTAssertTrue(resolved is SavedQueue)
  }

  @MainActor
  func testDeleteSavedQueueRemovesItsSystemPlaylists() throws {
    let fetchAllPlaylists = PlaylistMO.fetchRequest()
    let before = (try? cdHelper.persistentContainer.viewContext.count(for: fetchAllPlaylists)) ?? -1
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [songA].map { $0 as AbstractPlayable })
    library.saveContext()
    library.deleteSavedQueue(saved)
    library.saveContext()
    let after = (try? cdHelper.persistentContainer.viewContext.count(for: fetchAllPlaylists)) ?? -2
    XCTAssertEqual(before, after)
    XCTAssertTrue(library.getSavedQueues().isEmpty)
  }
}
