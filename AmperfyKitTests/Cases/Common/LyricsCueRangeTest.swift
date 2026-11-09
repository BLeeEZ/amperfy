//
//  LyricsCueRangeTest.swift
//  AmperfyKitTests
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
import CoreMedia
import XCTest

class LyricsCueRangeTest: XCTestCase {
  private func cue(_ value: String, _ byteStart: Int, _ byteEnd: Int, start: Int = 0) -> LyricsCue {
    var cue = LyricsCue()
    cue.start = start
    cue.value = value
    cue.byteStart = byteStart
    cue.byteEnd = byteEnd
    return cue
  }

  private func text(of cue: LyricsCue, in value: String) -> String? {
    guard let range = cue.range(in: value) else { return nil }
    return String(value[range])
  }

  func testAsciiRange() {
    XCTAssertEqual(text(of: cue("I", 0, 0), in: "I love you"), "I")
    XCTAssertEqual(text(of: cue("love", 2, 5), in: "I love you"), "love")
    XCTAssertEqual(text(of: cue("you", 7, 9), in: "I love you"), "you")
  }

  func testTurkishMultiByteRange() {
    let value = "Çağla ışığında"
    XCTAssertEqual(value.count, 14)
    XCTAssertEqual(value.utf8.count, 21)
    XCTAssertEqual(text(of: cue("Çağla", 0, 6), in: value), "Çağla")
    XCTAssertEqual(text(of: cue("ışığında", 8, 20), in: value), "ışığında")
  }

  func testKoreanRange() {
    XCTAssertEqual(text(of: cue("눈", 0, 2), in: "눈 love"), "눈")
    XCTAssertEqual(text(of: cue("love", 4, 7), in: "눈 love"), "love")
  }

  func testEmojiRange() {
    XCTAssertEqual(text(of: cue("🎵", 0, 3), in: "🎵 la"), "🎵")
    XCTAssertEqual(text(of: cue("la", 5, 6), in: "🎵 la"), "la")
  }

  func testByteEndIsInclusive() {
    let value = "Çağla ışığında"
    XCTAssertEqual(cue("Çağla", 0, 6).byteRange(in: value).map { String(value[$0]) }, "Çağla")
    XCTAssertEqual(cue("Çağl", 0, 5).byteRange(in: value).map { String(value[$0]) }, "Çağl")
    XCTAssertEqual(
      cue("ışığında", 8, 20).byteRange(in: value).map { String(value[$0]) },
      "ışığında"
    )
  }

  func testOutOfRangeFallsBackToSearch() {
    XCTAssertEqual(text(of: cue("you", 7, 99), in: "I love you"), "you")
    XCTAssertNil(cue("you", 7, 99).byteRange(in: "I love you"))
  }

  func testOutOfRangeWithoutMatchIsNil() {
    XCTAssertNil(cue("nope", 30, 33).range(in: "I love you"))
    XCTAssertNil(cue("nope", -1, 3).range(in: "I love you"))
    XCTAssertNil(cue("love", 5, 2).byteRange(in: "I love you"))
  }

  func testCharacterOffsetsFallBackToSearch() {
    // Character offsets instead of byte offsets point at "a ışı"
    let value = "Çağla ışığında"
    XCTAssertEqual(cue("ışığında", 6, 13).byteRange(in: value).map { String(value[$0]) }, "a ışı")
    XCTAssertEqual(text(of: cue("ışığında", 6, 13), in: value), "ışığında")
  }

  func testMidScalarOffsetIsRejected() {
    // Byte 9 is the second byte of "ı"
    let value = "Çağla ışığında"
    XCTAssertNil(cue("ışığında", 9, 20).byteRange(in: value))
    XCTAssertEqual(text(of: cue("ışığında", 9, 20), in: value), "ışığında")
    XCTAssertNil(cue("xyz", 1, 3).range(in: value))
  }

  func testValueMismatchFallsBackToSearch() {
    // The bytes point at "love", but the cue text is "you"
    XCTAssertEqual(text(of: cue("you", 2, 5), in: "I love you"), "you")
  }

  func testCueRangesOfCueLine() throws {
    var cueLine = LyricsCueLine()
    cueLine.value = "Çağla ışığında"
    cueLine.cues = [cue("Çağla", 0, 6), cue("ışığında", 8, 20)]
    let ranges = try XCTUnwrap(cueLine.cueRanges(in: "Çağla ışığında"))
    XCTAssertEqual(ranges.map { String(cueLine.value[$0]) }, ["Çağla", "ışığında"])
  }

  func testCueRangesShiftIntoLongerLine() throws {
    // The cueLine holds the text of one agent only. Its byte offsets refer to that text.
    var cueLine = LyricsCueLine()
    cueLine.value = "ışığında"
    cueLine.cues = [cue("ışığ", 0, 7), cue("ında", 8, 12)]
    let line = "Çağla ışığında"
    let ranges = try XCTUnwrap(cueLine.cueRanges(in: line))
    XCTAssertEqual(ranges.map { String(line[$0]) }, ["ışığ", "ında"])
  }

  func testRepeatedWordSearchMovesForward() throws {
    var cueLine = LyricsCueLine()
    cueLine.value = "wow wow wow"
    // Wrong offsets for every cue, so each range comes from the search
    cueLine.cues = [cue("wow", 1, 3), cue("wow", 1, 3), cue("wow", 1, 3)]
    let line = "wow wow wow"
    let ranges = try XCTUnwrap(cueLine.cueRanges(in: line))
    XCTAssertEqual(ranges.map { line.utf8.distance(from: line.startIndex, to: $0.lowerBound) }, [
      0,
      4,
      8,
    ])
  }

  func testCueRangesNilIfOneCueIsMissing() {
    var cueLine = LyricsCueLine()
    cueLine.value = "I love you"
    cueLine.cues = [cue("I", 0, 0), cue("hate", 2, 5)]
    XCTAssertNil(cueLine.cueRanges(in: "I love you"))
  }

  func testActiveCueIndex() {
    var cueLine = LyricsCueLine()
    var first = cue("Çağla", 0, 6, start: 1000)
    first.end = 1600
    var second = cue("ışığında", 8, 20, start: 1700)
    second.end = 2500
    cueLine.cues = [first, second]

    XCTAssertNil(cueLine.activeCueIndex(at: 999))
    XCTAssertEqual(cueLine.activeCueIndex(at: 1000), 0)
    XCTAssertEqual(cueLine.activeCueIndex(at: 1599), 0)
    // In the gap after the end of a cue, the cue stays active until the next cue starts
    XCTAssertEqual(cueLine.activeCueIndex(at: 1650), 0)
    XCTAssertEqual(cueLine.activeCueIndex(at: 1700), 1)
    XCTAssertEqual(cueLine.activeCueIndex(at: 9000), 1)
  }

  func testProgressUsesCueEnd() throws {
    var cueLine = LyricsCueLine()
    var first = cue("Çağla ", 0, 7, start: 1000)
    first.end = 1600
    var second = cue("ışığında", 8, 20, start: 1700)
    second.end = 2500
    cueLine.cues = [first, second]

    XCTAssertNil(cueLine.progress(at: 999))
    XCTAssertEqual(cueLine.progress(at: 1000), LyricsCueProgress(cueIndex: 0, fraction: 0))
    let middle = try XCTUnwrap(cueLine.progress(at: 1300))
    XCTAssertEqual(middle.cueIndex, 0)
    XCTAssertEqual(middle.fraction, 0.5, accuracy: 0.0001)
    // after its end the cue stays fully sung until the next cue starts
    XCTAssertEqual(cueLine.progress(at: 1650), LyricsCueProgress(cueIndex: 0, fraction: 1))
    XCTAssertEqual(cueLine.progress(at: 1700), LyricsCueProgress(cueIndex: 1, fraction: 0))
    XCTAssertEqual(cueLine.progress(at: 9000), LyricsCueProgress(cueIndex: 1, fraction: 1))
  }

  func testProgressWithoutCueEnd() throws {
    // Enhanced LRC has start times only: a cue ends where the next one starts
    var cueLine = LyricsCueLine()
    cueLine.end = 3000
    cueLine.cues = [cue("one ", 0, 3, start: 1000), cue("two", 4, 6, start: 2000)]

    XCTAssertEqual(try XCTUnwrap(cueLine.progress(at: 1250)).fraction, 0.25, accuracy: 0.0001)
    // the last cue ends with the cue line
    XCTAssertEqual(try XCTUnwrap(cueLine.progress(at: 2500)).fraction, 0.5, accuracy: 0.0001)

    cueLine.end = nil
    XCTAssertEqual(cueLine.progress(at: 2500), LyricsCueProgress(cueIndex: 1, fraction: 1))
  }

  func testProgressOfZeroLengthCue() {
    var cueLine = LyricsCueLine()
    var only = cue("hey", 0, 2, start: 1000)
    only.end = 1000
    cueLine.cues = [only]
    XCTAssertEqual(cueLine.progress(at: 1000), LyricsCueProgress(cueIndex: 0, fraction: 1))
  }

  func testPlaybackClockRunsSmoothlyBetweenPlayerSteps() {
    var clock = LyricsPlaybackClock()
    XCTAssertEqual(clock.time(playerTime: 10.0, rate: 1, hostTime: 100.0), 10.0)
    // the player time changes in steps, the clock follows the host time
    XCTAssertEqual(
      clock.time(playerTime: 10.0, rate: 1, hostTime: 100.016),
      10.016,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      clock.time(playerTime: 10.046, rate: 1, hostTime: 100.033),
      10.033,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      clock.time(playerTime: 10.046, rate: 1, hostTime: 100.050),
      10.050,
      accuracy: 0.0001
    )
  }

  func testPlaybackClockFollowsPlayerAfterDrift() {
    var clock = LyricsPlaybackClock()
    _ = clock.time(playerTime: 10.0, rate: 1, hostTime: 100.0)
    // a seek moves the player time far away from the prediction
    XCTAssertEqual(clock.time(playerTime: 42.0, rate: 1, hostTime: 100.016), 42.0)
    XCTAssertEqual(
      clock.time(playerTime: 42.0, rate: 1, hostTime: 100.032),
      42.016,
      accuracy: 0.0001
    )
    // the player stops: the prediction runs away and the clock goes back to the player time
    XCTAssertEqual(clock.time(playerTime: 42.0, rate: 1, hostTime: 100.2), 42.0)
  }

  func testPlaybackClockUsesRate() {
    var clock = LyricsPlaybackClock()
    _ = clock.time(playerTime: 10.0, rate: 1.5, hostTime: 100.0)
    XCTAssertEqual(
      clock.time(playerTime: 10.0, rate: 1.5, hostTime: 100.04),
      10.06,
      accuracy: 0.0001
    )
    // a new rate takes the player time again
    XCTAssertEqual(clock.time(playerTime: 10.05, rate: 1, hostTime: 100.05), 10.05)
    clock.reset()
    XCTAssertEqual(clock.time(playerTime: 3.0, rate: 1, hostTime: 200.0), 3.0)
  }

  func testActiveCueIndexWithoutCues() {
    XCTAssertNil(LyricsCueLine().activeCueIndex(at: 1000))
  }

  func testMainCueLineIsFirstOfIndex() {
    var lyrics = StructuredLyrics()
    var main = LyricsCueLine()
    main.index = 1
    main.agentId = "v1"
    var background = LyricsCueLine()
    background.index = 1
    background.agentId = "v2"
    lyrics.cueLines = [main, background]

    XCTAssertEqual(lyrics.mainCueLine(forLine: 1)?.agentId, "v1")
    XCTAssertNil(lyrics.mainCueLine(forLine: 0))
  }

  func testOffsetApplied() {
    var lyrics = StructuredLyrics()
    var line = LyricsLine()
    line.start = 2000

    lyrics.offset = 0
    XCTAssertEqual(lyrics.lyricsTime(at: CMTime(value: 1500, timescale: 1000)), 1500)
    XCTAssertEqual(lyrics.playbackSeconds(of: line), 2.0, accuracy: 0.0001)

    // Positive offset: the lyrics appear sooner
    lyrics.offset = 300
    XCTAssertEqual(lyrics.lyricsTime(at: CMTime(value: 1500, timescale: 1000)), 1800)
    XCTAssertEqual(lyrics.playbackSeconds(of: line), 1.7, accuracy: 0.0001)

    // Negative offset: the lyrics appear later
    lyrics.offset = -300
    XCTAssertEqual(lyrics.lyricsTime(at: CMTime(value: 1500, timescale: 1000)), 1200)
    XCTAssertEqual(lyrics.playbackSeconds(of: line), 2.3, accuracy: 0.0001)

    // A seek target is never before the start of the track
    lyrics.offset = 5000
    XCTAssertEqual(lyrics.playbackSeconds(of: line), 0.0, accuracy: 0.0001)
  }

  func testInvalidPlaybackTimeGivesOffset() {
    var lyrics = StructuredLyrics()
    lyrics.offset = 100
    XCTAssertEqual(lyrics.lyricsTime(at: .invalid), 100)
  }
}
