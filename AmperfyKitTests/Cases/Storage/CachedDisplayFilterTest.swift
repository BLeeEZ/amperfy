//
//  CachedDisplayFilterTest.swift
//  AmperfyKitTests
//
//  Created by Jayce Slesar on 25.07.26.
//  Copyright (c) 2026 Jayce Slesar. All rights reserved.
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

/// Covers the `.cached` display filters backing the "Downloaded Albums" and
/// "Downloaded Artists" library entries. Downloading itself cannot be exercised
/// here — the playable downloader uses a background URLSession — so these tests
/// simulate a downloaded song by setting `relFilePath`, which is exactly what
/// `isCached` and the cached fetch predicates key off.
@MainActor
class CachedDisplayFilterTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
  }

  override func tearDown() {}

  /// artist -> album -> song, with the song optionally marked as downloaded.
  @discardableResult
  private func makeChain(downloaded: Bool, id: String) -> (Artist, Album, Song) {
    let artist = library.createArtist(account: account)
    artist.id = "artist-\(id)"
    let album = library.createAlbum(account: account)
    album.id = "album-\(id)"
    album.artist = artist
    let song = library.createSong(account: account)
    song.id = "song-\(id)"
    song.album = album
    song.artist = artist
    if downloaded {
      song.relFilePath = URL(string: "downloaded-\(id).flac")
    }
    library.saveContext()
    return (artist, album, song)
  }

  func testDownloadedSongIsCached() {
    let (_, _, downloaded) = makeChain(downloaded: true, id: "a")
    let (_, _, streamed) = makeChain(downloaded: false, id: "b")
    XCTAssertTrue(downloaded.isCached)
    XCTAssertFalse(streamed.isCached)
  }

  func testCachedAlbumFilterMatchesOnlyDownloaded() {
    let (_, downloadedAlbum, _) = makeChain(downloaded: true, id: "a")
    let (_, streamedAlbum, _) = makeChain(downloaded: false, id: "b")
    let predicate = library.getFetchPredicate(albumsDisplayFilter: .cached)
    XCTAssertTrue(predicate.evaluate(with: downloadedAlbum.managedObject))
    XCTAssertFalse(predicate.evaluate(with: streamedAlbum.managedObject))
  }

  func testCachedArtistFilterMatchesOnlyDownloaded() {
    let (downloadedArtist, _, _) = makeChain(downloaded: true, id: "a")
    let (streamedArtist, _, _) = makeChain(downloaded: false, id: "b")
    let predicate = library.getFetchPredicate(artistsDisplayFilter: .cached)
    XCTAssertTrue(predicate.evaluate(with: downloadedArtist.managedObject))
    XCTAssertFalse(predicate.evaluate(with: streamedArtist.managedObject))
  }

  func testCachedSongFilterMatchesOnlyDownloaded() {
    let (_, _, downloadedSong) = makeChain(downloaded: true, id: "a")
    let (_, _, streamedSong) = makeChain(downloaded: false, id: "b")
    let predicate = library.getFetchPredicate(songsDisplayFilter: .cached)
    XCTAssertTrue(predicate.evaluate(with: downloadedSong.managedObject))
    XCTAssertFalse(predicate.evaluate(with: streamedSong.managedObject))
  }

  /// The `.all` filter must keep matching everything — the new case must not
  /// narrow the existing screens.
  func testAllFilterStillMatchesUndownloaded() {
    let (_, streamedAlbum, _) = makeChain(downloaded: false, id: "b")
    let predicate = library.getFetchPredicate(albumsDisplayFilter: .all)
    XCTAssertTrue(predicate.evaluate(with: streamedAlbum.managedObject))
  }

  /// A library type introduced by a newer app version must land in `notUsed`
  /// rather than vanishing, otherwise it is unreachable from the Library editor.
  func testNewLibraryTypesRemainReachableAfterDecoding() throws {
    // Simulate settings persisted before the downloaded entries existed.
    let legacyInUse: [LibraryDisplayType] = [.artists, .albums, .songs]
    let legacyNotUsed: [LibraryDisplayType] = [.genres, .playlists]
    let encoded = try JSONEncoder().encode([
      "combined": [legacyInUse.map(\.rawValue), legacyNotUsed.map(\.rawValue)],
    ])
    let decoded = try JSONDecoder().decode(LibraryDisplaySettings.self, from: encoded)

    XCTAssertEqual(decoded.inUse, legacyInUse)
    XCTAssertTrue(decoded.notUsed.contains(.downloadedAlbums))
    XCTAssertTrue(decoded.notUsed.contains(.downloadedArtists))
    // Nothing may be lost or duplicated in the process.
    let all = Set(decoded.inUse).union(decoded.notUsed)
    XCTAssertEqual(all, Set(LibraryDisplayType.allCases))
  }
}
