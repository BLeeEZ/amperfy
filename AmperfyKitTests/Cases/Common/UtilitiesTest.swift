//
//  UtilitiesTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 09.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

// MARK: - UtilitiesTest

class UtilitiesTest: XCTestCase {
  func testInt16Valid() {
    XCTAssertTrue(Int16.isValid(value: Int(Int16.max)))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.min)))
    XCTAssertTrue(Int16.isValid(value: Int(0)))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.min) + 1))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.max) - 1))
  }

  func testInt16Invalid() {
    XCTAssertFalse(Int16.isValid(value: Int(Int16.max) + 1))
    XCTAssertFalse(Int16.isValid(value: Int(Int16.min) - 1))
    XCTAssertFalse(Int16.isValid(value: Int(Int32.min)))
    XCTAssertFalse(Int16.isValid(value: Int(Int32.max)))
  }

  func testInt32Valid() {
    XCTAssertTrue(Int32.isValid(value: Int(Int32.max)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.min)))
    XCTAssertTrue(Int32.isValid(value: Int(0)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.min + 1)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.max - 1)))
  }

  func testInt32Invalid() {
    XCTAssertFalse(Int32.isValid(value: Int(Int32.max) + 1))
    XCTAssertFalse(Int32.isValid(value: Int(Int32.min) - 1))
    XCTAssertFalse(Int32.isValid(value: Int(Int64.min)))
    XCTAssertFalse(Int32.isValid(value: Int(Int64.max)))
  }
}

// MARK: - SplitMix64

/// Deterministic generator so every assertion is reproducible
private struct SplitMix64: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

// MARK: - Track

private struct Track: Equatable {
  let id: String
  let artist: String?
  let album: String?
}

// MARK: - BalancedShuffleTest

class BalancedShuffleTest: XCTestCase {
  /// spec: (artist, albums, songs per album)
  private func library(_ spec: [(String, Int, Int)]) -> [Track] {
    spec.flatMap { artist, albums, songs in
      (0 ..< albums * songs).map {
        Track(id: "\(artist)-\($0)", artist: artist, album: "\(artist)-album-\($0 % albums)")
      }
    }
  }

  private func singles(_ count: Int) -> [Track] {
    library((0 ..< count).map { ("single\($0)", 1, 1) })
  }

  private func shuffle(
    _ tracks: [Track],
    keepingFirst firstIndex: Int? = nil,
    using generator: inout SplitMix64
  )
    -> [Track] {
    tracks.balancedShuffled(
      artistKey: { $0.artist },
      albumKey: { $0.album },
      keepingFirst: firstIndex,
      using: &generator
    )
  }

  private func runs(_ tracks: [Track], times: Int, seed: UInt64 = 1) -> [[Track]] {
    var generator = SplitMix64(state: seed)
    return (0 ..< times).map { _ in shuffle(tracks, using: &generator) }
  }

  private func adjacentRepeats(_ list: [Track], key: (Track) -> String? = { $0.artist }) -> Int {
    zip(list, list.dropFirst()).filter { key($0) == key($1) }.count
  }

  private func longestRun(_ list: [Track]) -> Int {
    var longest = list.isEmpty ? 0 : 1
    var run = 1
    for (previous, track) in zip(list, list.dropFirst()) {
      run = track.artist == previous.artist ? run + 1 : 1
      longest = max(longest, run)
    }
    return longest
  }

  private func sortedIds(_ list: [Track]) -> [String] {
    list.map { $0.id }.sorted()
  }

  func testReturnsPermutation() {
    for count in [0, 1, 2, 1000] {
      let tracks = (0 ..< count).map {
        Track(id: "t\($0)", artist: ["a", "b", "c", "c"][$0 % 4], album: "album-\($0 % 3)")
      }
      var generator = SplitMix64(state: 7)
      let result = shuffle(tracks, using: &generator)
      XCTAssertEqual(sortedIds(result), sortedIds(tracks))
    }
  }

  func testIsDeterministicForSameGenerator() {
    let tracks = library([("a", 2, 5), ("b", 1, 7)]) + singles(20)
    var first = SplitMix64(state: 42)
    var second = SplitMix64(state: 42)
    XCTAssertEqual(shuffle(tracks, using: &first), shuffle(tracks, using: &second))
  }

  func testWorksWithSystemGeneratorAndWithoutKeys() {
    let tracks = library([("a", 1, 10)])
    let result = tracks.balancedShuffled(artistKey: { _ in nil }, albumKey: { _ in nil })
    XCTAssertEqual(sortedIds(result), sortedIds(tracks))
  }

  func testNeverPlaysSameArtistTwiceInARowWhenAvoidable() {
    let cases: [[Track]] = [
      library((0 ..< 10).map { ("a\($0)", 2, 5) }),
      library([("a", 2, 5)]) + singles(90),
      library([("a", 5, 10), ("b", 3, 10), ("c", 2, 10)]),
      library([("a", 4, 10)]) + singles(60),
      library([("a", 5, 10)]) + singles(50),
    ]
    for tracks in cases {
      for result in runs(tracks, times: 200) {
        XCTAssertEqual(adjacentRepeats(result), 0)
      }
    }
  }

  func testSplitsUnavoidableRepeatsIntoEvenRuns() {
    for (dominant, others, minimalRepeats, maxRun) in [(60, 40, 19, 2), (80, 20, 59, 4)] {
      let tracks = library([("a", 4, dominant / 4)]) + singles(others)
      for result in runs(tracks, times: 200) {
        XCTAssertEqual(adjacentRepeats(result), minimalRepeats)
        XCTAssertEqual(longestRun(result), maxRun)
      }
    }
  }

  func testSpreadsAlbumsOfSingleArtist() {
    let tracks = library([("a", 3, 10)])
    let repeats = runs(tracks, times: 200).map { adjacentRepeats($0, key: { $0.album }) }
    // a uniform shuffle averages 29 * 9/29 = 9 adjacent songs from one album
    XCTAssertLessThan(Double(repeats.reduce(0, +)) / Double(repeats.count), 1)
  }

  func testTreatsSongsWithoutArtistAsDistinctArtists() {
    for artist in ["", nil] {
      let tracks = (0 ..< 10).map { Track(id: "t\($0)", artist: artist, album: nil) }
        + library([("b", 1, 5)])
      let results = runs(tracks, times: 200)
      for result in results {
        XCTAssertEqual(sortedIds(result), sortedIds(tracks))
      }
      // as one artist they would hold 10 of 15 songs and always open the queue
      XCTAssertTrue(results.contains { $0[0].artist == "b" }, "\(String(describing: artist))")
    }
  }

  func testSpreadsSongsOfArtistEvenlyAcrossQueue() {
    let tracks = library([("a", 1, 10)]) + singles(90)
    let smallestGaps = runs(tracks, times: 200).map { result in
      let positions = result.indices.filter { result[$0].artist == "a" }
      return zip(positions, positions.dropFirst()).map { $1 - $0 }.min()!
    }
    // a uniform order with its neighbours separated averages about 2
    XCTAssertGreaterThan(Double(smallestGaps.reduce(0, +)) / Double(smallestGaps.count), 4)
  }

  func testKeepsFirstElementAndSpreadsRestAroundIt() {
    let tracks = library((0 ..< 10).map { ("a\($0)", 2, 5) })
    var generator = SplitMix64(state: 3)
    for _ in 0 ..< 200 {
      let firstIndex = Int.random(in: 0 ..< tracks.count, using: &generator)
      let result = shuffle(tracks, keepingFirst: firstIndex, using: &generator)
      XCTAssertEqual(result[0], tracks[firstIndex])
      XCTAssertEqual(sortedIds(result), sortedIds(tracks))
      XCTAssertEqual(adjacentRepeats(result), 0)
    }
  }

  func testIgnoresFirstIndexOutOfRange() {
    let tracks = library([("a", 1, 3), ("b", 1, 3)])
    var generator = SplitMix64(state: 1)
    let result = shuffle(tracks, keepingFirst: 99, using: &generator)
    XCTAssertEqual(sortedIds(result), sortedIds(tracks))
  }

  func testGivesEveryTrackEvenChanceOfEveryPosition() {
    let tracks = library([("a", 2, 5)]) + singles(90)
    let watched = [tracks[0], tracks[50]]
    let results = runs(tracks, times: 3000, seed: 11)
    for track in watched {
      var deciles = [Int](repeating: 0, count: 10)
      for result in results {
        deciles[result.firstIndex(of: track)! / 10] += 1
      }
      for count in deciles {
        let share = Double(count) / Double(results.count)
        XCTAssertGreaterThan(share, 0.07)
        XCTAssertLessThan(share, 0.13)
      }
    }
  }

  func testArtistWithManySongsOpensAsOftenAsByChance() {
    let tracks = library([("a", 2, 5)]) + singles(90)
    let results = runs(tracks, times: 3000, seed: 5)
    let share = Double(results.filter { $0[0].artist == "a" }.count) / Double(results.count)
    XCTAssertGreaterThan(share, 0.07)
    XCTAssertLessThan(share, 0.13)
  }

  func testShufflesLargeLibrariesQuickly() {
    let cases: [[Track]] = [
      library([("a", 200, 100)]),
      library([("a", 190, 100)]) + singles(1000),
      library([("a", 100, 100)]) + singles(10000),
      library((0 ..< 100).map { ("a\($0)", 5, 20) }),
    ]
    for tracks in cases {
      var generator = SplitMix64(state: 1)
      let start = Date()
      let result = shuffle(tracks, using: &generator)
      // generous for debug builds; a quadratic repair pass takes minutes here
      XCTAssertLessThan(Date().timeIntervalSince(start), 10)
      XCTAssertEqual(result.count, tracks.count)
    }
  }
}
