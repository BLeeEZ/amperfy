//
//  SsLyricsBySongId4ParserTest.swift
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

/// Enhanced lyrics with agents, several cue lines for one line, an offset and layers
class SsLyricsBySongId4ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "getLyricsBySongId_example_4")
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

    XCTAssertEqual(lyricsList.lyrics.count, 3)

    let main = lyricsList.lyrics[0]
    XCTAssertEqual(main.kind, .main)
    XCTAssertEqual(main.offset, -250)
    XCTAssertEqual(main.agents.count, 2)
    XCTAssertEqual(main.agents[0].id, "lead")
    XCTAssertEqual(main.agents[0].role, "main")
    XCTAssertEqual(main.agents[0].name, "Lead Singer")
    XCTAssertEqual(main.agents[1].id, "backing")
    XCTAssertEqual(main.agents[1].role, "bg")
    XCTAssertNil(main.agents[1].name)

    XCTAssertEqual(main.line.count, 2)
    XCTAssertEqual(main.line[0].end, 2900)
    XCTAssertEqual(main.line[1].end, 4500)
    XCTAssertEqual(main.lastLineEnd, 4500)

    XCTAssertEqual(main.cueLines.count, 3)
    XCTAssertEqual(main.cueLines.map { $0.index }, [0, 0, 1])
    XCTAssertEqual(main.cueLines.map { $0.agentId }, ["lead", "backing", "lead"])
    XCTAssertEqual(main.mainCueLine(forLine: 0)?.agentId, "lead")
    XCTAssertEqual(main.mainCueLine(forLine: 1)?.cues.map { $0.value }, ["Good", "bye"])

    // the cue lines hold the text of one agent only, the line holds both
    let line = main.line[0].value
    let leadRanges = main.cueLines[0].cueRanges(in: line)
    XCTAssertEqual(
      leadRanges?.map { line.utf8.distance(from: line.startIndex, to: $0.lowerBound) },
      [0]
    )
    let backingRanges = main.cueLines[1].cueRanges(in: line)
    XCTAssertEqual(backingRanges?.map { String(line[$0]) }, ["hello"])
    XCTAssertEqual(
      backingRanges?.map { line.utf8.distance(from: line.startIndex, to: $0.lowerBound) },
      [7]
    )

    let pronunciation = lyricsList.lyrics[1]
    XCTAssertEqual(pronunciation.kind, .pronunciation)
    XCTAssertEqual(pronunciation.cueLines.count, 1)
    XCTAssertTrue(pronunciation.agents.isEmpty)

    // an unknown kind falls back to main
    let unknown = lyricsList.lyrics[2]
    XCTAssertEqual(unknown.kind, .main)
    XCTAssertFalse(unknown.synced)
    XCTAssertTrue(unknown.cueLines.isEmpty)

    XCTAssertEqual(lyricsList.getFirstSyncedLyricsOrUnsyncedAsDefault()?.displayTitle, "Agents")
  }
}
