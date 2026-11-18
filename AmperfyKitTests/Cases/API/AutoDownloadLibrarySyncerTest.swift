//
//  AutoDownloadLibrarySyncerTest.swift
//  AmperfyKitTests
//
//  Created by RaulitoRS97 on 18.11.26.
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
final class AutoDownloadLibrarySyncerTest: XCTestCase {
  var storage: PersistentStorage!
  var librarySyncer: MOCK_LibrarySyncer!
  var syncer: AutoDownloadLibrarySyncer!

  override func setUp() async throws {
    let cdHelper = CoreDataHelper()
    let library = cdHelper.createSeededStorage()
    storage = PersistentStorage(
      coreDataManager: MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    )
    librarySyncer = MOCK_LibrarySyncer()
    syncer = AutoDownloadLibrarySyncer(
      storage: storage,
      account: library.getAccount(info: TestAccountInfo.create1()),
      librarySyncer: librarySyncer,
      playableDownloadManager: MOCK_SongDownloader()
    )
    // the settings (UserDefaults) are shared with the host app: restore them afterwards
    let userKey = PersistentStorage.UserDefaultsKey.SettingsUser.rawValue
    let savedUserData = UserDefaults.standard.data(forKey: userKey)
    addTeardownBlock { UserDefaults.standard.set(savedUserData, forKey: userKey) }
  }

  func testNewestAlbumsAreRequestedInOnlineMode() async throws {
    storage.settings.user.isOfflineMode = false
    try await syncer.syncNewestLibraryElements()
    XCTAssertEqual(librarySyncer.syncNewestAlbumsCount, 1)
  }

  func testNewestAlbumsAreNotRequestedInOfflineMode() async throws {
    storage.settings.user.isOfflineMode = true
    try await syncer.syncNewestLibraryElements()
    XCTAssertEqual(librarySyncer.syncNewestAlbumsCount, 0)
  }

  func testNewestPodcastEpisodesAreRequestedInOnlineMode() async throws {
    storage.settings.user.isOfflineMode = false
    _ = try await syncer.syncNewestPodcastEpisodes()
    XCTAssertEqual(librarySyncer.syncNewestPodcastEpisodesCount, 1)
  }

  func testNewestPodcastEpisodesAreNotRequestedInOfflineMode() async throws {
    storage.settings.user.isOfflineMode = true
    let newEpisodes = try await syncer.syncNewestPodcastEpisodes()
    XCTAssertEqual(librarySyncer.syncNewestPodcastEpisodesCount, 0)
    XCTAssertTrue(newEpisodes.isEmpty)
  }
}
