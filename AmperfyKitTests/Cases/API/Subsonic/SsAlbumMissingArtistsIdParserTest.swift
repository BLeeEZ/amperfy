//
//  SsAlbumMissingArtistsIdParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 09.01.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class SsAlbumMissingArtistsIdParserTest: AbstractSsParserTest {
  let albumId = "101941fb3433f9748a21d087cdccea3c"

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "album_missing_artistId")
    ssParserDelegate = SsSongParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
    createTestAlbum()
  }

  func createTestAlbum() {
    let album = library.createAlbum()
    album.id = albumId
    album.name = "FabricLive 25: High Contrast"
    album.artwork?.url = "9ad05e5fb1ee14426973cce9fb0036dc"
  }

  override func checkCorrectParsing() {
    let fetchRequest = SongMO.trackNumberSortedFetchRequest
    let album = library.getAlbum(id: albumId, isDetailFaultResolution: true)!
    fetchRequest.predicate = library.getFetchPredicate(forAlbum: album)

    let songsMO = try? context.fetch(fetchRequest)
    guard let songsMO = songsMO else { XCTFail(); return }
    XCTAssertEqual(songsMO.count, 22)

    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    guard let songs = songs else { XCTFail(); return }

    var song = songs[0]
    XCTAssertEqual(1, song.track)
    XCTAssertEqual("Adam F", song.artist?.name)
    XCTAssertEqual(albumId, song.album?.id)
    song = songs[1]
    XCTAssertEqual(2, song.track)
    XCTAssertEqual("London Elektricity", song.artist?.name)
    song = songs[2]
    XCTAssertEqual(3, song.track)
    XCTAssertEqual("DJ Marky, Bungle & DJ Roots", song.artist?.name)
    song = songs[3]
    XCTAssertEqual(4, song.track)
    XCTAssertEqual("Logistics", song.artist?.name)
    song = songs[4]
    XCTAssertEqual(5, song.track)
    XCTAssertEqual("Cyantific & Logistics", song.artist?.name)
    song = songs[5]
    XCTAssertEqual(6, song.track)
    XCTAssertEqual("Funky Technicians", song.artist?.name)
    song = songs[6]
    XCTAssertEqual(7, song.track)
    XCTAssertEqual("Martyn", song.artist?.name)
    song = songs[21]
    XCTAssertEqual(22, song.track)
    XCTAssertEqual("High Contrast", song.artist?.name)
    XCTAssertEqual(albumId, song.album?.id)

    let localArtist = library.getArtistLocal(name: "Logistics")
    XCTAssertEqual(songs[3].artist, localArtist)
    XCTAssertEqual(2, localArtist?.songs.count)
    // songCount is denormalized -> will be updated at save context
    library.saveContext()
    XCTAssertEqual(2, localArtist?.songCount)
  }
}
