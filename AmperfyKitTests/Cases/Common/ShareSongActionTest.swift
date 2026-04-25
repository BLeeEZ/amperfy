//
//  ShareSongActionTest.swift
//  AmperfyKitTests
//
//  Created by Olivier Butler on 19.04.26.
//  Copyright (c) 2026 Olivier Butler. All rights reserved.
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
import UIKit
import XCTest

@MainActor
class ShareSongActionTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var songDownloader: MOCK_SongDownloader!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    songDownloader = MOCK_SongDownloader()
  }

  // MARK: - Pure helpers

  func testSanitizedFileNameReplacesSlashAndColon() {
    guard let cachedSong = library.getSong(for: account, id: "36") else {
      XCTFail("Seeded cached song \"36\" not found")
      return
    }
    cachedSong.title = "A/B:C"
    cachedSong.artist?.name = "D/E:F"
    XCTAssertEqual(
      ShareSongAction.sanitizedFileName(playable: cachedSong),
      "D-E-F - A-B-C"
    )
  }

  // MARK: - Branching behaviour

  func testShareWithCachedSongDoesNotCallDownloader() {
    guard let cachedSong = library.getSong(for: account, id: "36") else {
      XCTFail("Seeded cached song \"36\" not found")
      return
    }
    ShareSongAction.share(
      playable: cachedSong,
      from: UIView(),
      presenter: UIViewController(),
      downloadManagerProvider: { self.songDownloader }
    )
    XCTAssertTrue(songDownloader.isNoDownloadRequested())
  }

  func testShareWithUncachedSongCallsDownloader() {
    guard let uncachedSong = library.getSong(for: account, id: "3") else {
      XCTFail("Seeded uncached song \"3\" not found")
      return
    }
    ShareSongAction.share(
      playable: uncachedSong,
      from: UIView(),
      presenter: UIViewController(),
      downloadManagerProvider: { self.songDownloader }
    )
    XCTAssertFalse(songDownloader.isNoDownloadRequested())
    XCTAssertEqual(songDownloader.downloadables.count, 1)
  }

  func testShareWithNilDownloadManagerProviderReturnsEarly() {
    guard let uncachedSong = library.getSong(for: account, id: "3") else {
      XCTFail("Seeded uncached song \"3\" not found")
      return
    }
    var providerInvocations = 0
    ShareSongAction.share(
      playable: uncachedSong,
      from: UIView(),
      presenter: UIViewController(),
      downloadManagerProvider: {
        providerInvocations += 1
        return nil
      }
    )
    XCTAssertEqual(providerInvocations, 1)
    XCTAssertTrue(songDownloader.isNoDownloadRequested())
  }
}
