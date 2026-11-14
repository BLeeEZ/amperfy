//
//  SsLyricsBySongId3ParserTest.swift
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
import XCTest

/// Enhanced lyrics (OpenSubsonic songLyrics v2) in the shape that Navidrome 0.64.2 sends
class SsLyricsBySongId3ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "getLyricsBySongId_example_3")
  }

  override func createParserDelegate() {
    ssParserDelegate = SsLyricsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func checkCorrectParsing() {
    guard let lyricsParser = ssParserDelegate as? SsLyricsParserDelegate,
          let lyricsList = lyricsParser.lyricsList
    else {
      XCTFail()
      return
    }
    prefetchIdTester.checkPrefetchIdCounts()

    XCTAssertEqual(lyricsList.lyrics.count, 2)

    let translation = lyricsList.lyrics[0]
    XCTAssertEqual(translation.kind, .translation)
    XCTAssertEqual(translation.lang, "tur")
    XCTAssertTrue(translation.synced)
    XCTAssertEqual(translation.line.count, 1)
    XCTAssertTrue(translation.cueLines.isEmpty)

    let main = lyricsList.lyrics[1]
    XCTAssertEqual(main.kind, .main)
    XCTAssertEqual(main.displayArtist, "Post Malone")
    XCTAssertEqual(main.displayTitle, "Wow.")
    XCTAssertEqual(main.lang, "en")
    XCTAssertEqual(main.offset, 0)
    XCTAssertTrue(main.synced)
    XCTAssertTrue(main.agents.isEmpty)
    XCTAssertEqual(main.line.count, 4)
    XCTAssertEqual(main.line[0].start, 9680)
    XCTAssertNil(main.line[0].end)
    XCTAssertEqual(main.line[0].value, "Here it's only a sample line with ten small cues")
    XCTAssertEqual(main.line[2].start, 14490)
    XCTAssertEqual(main.line[2].end, 16900)
    XCTAssertEqual(main.line[2].value, "Çağla ışığında")

    XCTAssertEqual(main.cueLines.count, 3)
    XCTAssertEqual(main.cueLines.map { $0.index }, [0, 1, 2])
    let first = main.cueLines[0]
    XCTAssertEqual(first.start, 9680)
    XCTAssertEqual(first.end, 11860)
    XCTAssertNil(first.agentId)
    XCTAssertEqual(first.value, main.line[0].value)
    XCTAssertEqual(first.cues.count, 10)
    // Navidrome keeps the trailing space in the cue text
    XCTAssertEqual(first.cues[0].value, "Here ")
    XCTAssertEqual(first.cues[0].start, 9680)
    XCTAssertEqual(first.cues[0].end, 9860)
    XCTAssertEqual(first.cues[0].byteStart, 0)
    XCTAssertEqual(first.cues[0].byteEnd, 4)
    XCTAssertEqual(first.cues[1].value, "it's ")
    XCTAssertEqual(first.cues[9].value, "cues")
    XCTAssertEqual(first.cues[9].byteEnd, 47)

    let turkish = main.cueLines[2]
    XCTAssertEqual(turkish.cues.map { $0.value }, ["Çağla ", "ışığında"])
    XCTAssertEqual(turkish.cues.map { $0.byteStart }, [0, 8])
    XCTAssertEqual(turkish.cues.map { $0.byteEnd }, [7, 20])

    // every cue of the response is found by its byte offsets
    for cueLine in main.cueLines {
      let text = main.line[cueLine.index].value
      for cue in cueLine.cues {
        guard let range = cue.byteRange(in: text) else {
          XCTFail("no byte range for cue \(cue.value)")
          continue
        }
        XCTAssertEqual(String(text[range]), cue.value)
      }
    }
    let turkishRanges = main.cueLines[2].cueRanges(in: main.line[2].value)
    XCTAssertEqual(turkishRanges?.map { String(main.line[2].value[$0]) }, ["Çağla ", "ışığında"])

    XCTAssertEqual(main.mainCueLine(forLine: 1)?.cues.count, 9)
    XCTAssertNil(main.mainCueLine(forLine: 3))
    XCTAssertNil(main.lastLineEnd, "the last line has no end and no word timing")

    // the main layer is preferred, though the translation comes first
    XCTAssertEqual(lyricsList.getFirstSyncedLyricsOrUnsyncedAsDefault()?.kind, .main)
  }
}
