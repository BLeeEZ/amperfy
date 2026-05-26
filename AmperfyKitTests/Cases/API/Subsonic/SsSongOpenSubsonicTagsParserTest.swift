//
//  SsSongOpenSubsonicTagsParserTest.swift
//  AmperfyKitTests
//
//  Created by Amperfy on 26.05.26.
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

/// Tests that every new OpenSubsonic field added in v50 is correctly parsed
/// by SsSongParserDelegate and stored on the Song entity.
///
/// Fixture: album_opensubsonic_tags_example_1.xml (3 songs)
///   ost1 – all new simple attributes + all new child element types
///   ost2 – contributor subRole + same-role grouping
///   ost3 – minimal song (no new fields); verifies state resets between songs
class SsSongOpenSubsonicTagsParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "album_opensubsonic_tags_example_1")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsSongParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      prefetch: prefetch,
      account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    let songs = library.getSongs(for: account).sorted { $0.id < $1.id }
    XCTAssertEqual(songs.count, 3)

    // MARK: ost1 – full OpenSubsonic tags

    let song1 = songs[0]
    XCTAssertEqual(song1.id, "ost1")

    // Simple numeric attributes
    XCTAssertEqual(song1.bpm, 120)
    XCTAssertEqual(song1.bitDepth, 24)
    XCTAssertEqual(song1.samplingRate, 44100)
    XCTAssertEqual(song1.channelCount, 2)

    // Simple string attributes
    XCTAssertEqual(song1.comment, "Test comment")
    XCTAssertEqual(song1.sortName, "Full Tag Sort")
    XCTAssertEqual(song1.musicBrainzId, "550e8400-e29b-41d4-a716-446655440000")
    XCTAssertEqual(song1.displayAlbumArtist, "Album Artist Display")
    XCTAssertEqual(song1.displayComposer, "John Smith")
    XCTAssertEqual(song1.explicitStatus, "explicit")

    // <artists> children must override the displayArtist attribute
    XCTAssertEqual(song1.artistsString, "Artist One, Artist Two")

    // <albumArtists> children
    XCTAssertEqual(song1.albumArtistsString, "Album Artist One")

    // <genres> children (multi-genre list, separate from primary genre entity)
    XCTAssertEqual(song1.genresList, "Rock, Metal")

    // Text-content child elements
    XCTAssertEqual(song1.isrcList, "USRC17607839")
    XCTAssertEqual(song1.moodsList, "Happy, Energetic")
    XCTAssertEqual(song1.groupingsList, "Group A")

    // Contributors: two distinct roles → two lines
    XCTAssertEqual(song1.contributorsString, "Composer: John Smith\nLyricist: Jane Doe")

    // MARK: ost2 – contributor subRole + same-role grouping

    let song2 = songs[1]
    XCTAssertEqual(song2.id, "ost2")

    // Both contributors share role="composer" subRole="orchestral" → one grouped line
    XCTAssertEqual(
      song2.contributorsString,
      "Composer (orchestral): Composer A, Composer B"
    )

    // No other new fields on song2
    XCTAssertEqual(song2.bpm, 0)
    XCTAssertNil(song2.comment)
    XCTAssertNil(song2.albumArtistsString)
    XCTAssertNil(song2.genresList)
    XCTAssertNil(song2.isrcList)
    XCTAssertNil(song2.moodsList)
    XCTAssertNil(song2.groupingsList)

    // MARK: ost3 – minimal song, verifies complete state reset between songs

    let song3 = songs[2]
    XCTAssertEqual(song3.id, "ost3")

    XCTAssertEqual(song3.bpm, 0)
    XCTAssertEqual(song3.bitDepth, 0)
    XCTAssertEqual(song3.samplingRate, 0)
    XCTAssertEqual(song3.channelCount, 0)
    XCTAssertNil(song3.comment)
    XCTAssertNil(song3.sortName)
    XCTAssertNil(song3.musicBrainzId)
    XCTAssertNil(song3.displayAlbumArtist)
    XCTAssertNil(song3.displayComposer)
    XCTAssertNil(song3.explicitStatus)
    XCTAssertNil(song3.albumArtistsString)
    XCTAssertNil(song3.genresList)
    XCTAssertNil(song3.isrcList)
    XCTAssertNil(song3.moodsList)
    XCTAssertNil(song3.groupingsList)
    XCTAssertNil(song3.contributorsString)

    // artistsString comes from the artist attribute fallback (no <artists> children)
    XCTAssertEqual(song3.artistsString, "Simple Artist")
  }
}
