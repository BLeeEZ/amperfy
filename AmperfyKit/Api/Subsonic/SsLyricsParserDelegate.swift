//
//  SsLyricsParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.06.24.
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

import CoreData
import Foundation
import UIKit

class SsLyricsParserDelegate: SsXmlParser {
  public var lyricsList: LyricsList?
  private var structuredLyrics: StructuredLyrics?
  private var lines: [LyricsLine]?
  private var currentLine: LyricsLine?
  private var currentCueLine: LyricsCueLine?
  private var currentCue: LyricsCue?

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )

    if elementName == "lyricsList" {
      lyricsList = LyricsList()
      structuredLyrics = nil
      lines = nil
      currentLine = nil
      currentCueLine = nil
      currentCue = nil
    } else if elementName == "structuredLyrics" {
      structuredLyrics = StructuredLyrics()
      structuredLyrics?.displayArtist = attributeDict["displayArtist"]
      structuredLyrics?.displayTitle = attributeDict["displayTitle"]
      structuredLyrics?.lang = attributeDict["lang"] ?? ""
      structuredLyrics?.kind = LyricsKind(rawValue: attributeDict["kind"] ?? "") ?? .main
      if let offsetStr = attributeDict["offset"], let offsetInt = Int(offsetStr) {
        structuredLyrics?.offset = offsetInt
      } else {
        structuredLyrics?.offset = 0
      }

      if let isSynced = attributeDict["synced"] {
        structuredLyrics?.synced = (isSynced == "true")
      } else {
        structuredLyrics?.synced = false
      }
      lines = [LyricsLine]()
      currentLine = nil
      currentCueLine = nil
      currentCue = nil
    } else if elementName == "line" {
      currentLine = LyricsLine()
      if let startStr = attributeDict["start"], let startInt = Int(startStr) {
        currentLine?.start = startInt
      }
      currentLine?.end = attributeDict["end"].flatMap { Int($0) }
    } else if elementName == "agent", structuredLyrics != nil {
      var agent = LyricsAgent()
      agent.id = attributeDict["id"] ?? ""
      agent.role = attributeDict["role"] ?? ""
      agent.name = attributeDict["name"]
      structuredLyrics?.agents.append(agent)
    } else if elementName == "cueLine", structuredLyrics != nil {
      currentCueLine = nil
      if let index = attributeDict["index"].flatMap({ Int($0) }) {
        var cueLine = LyricsCueLine()
        cueLine.index = index
        cueLine.start = attributeDict["start"].flatMap { Int($0) }
        cueLine.end = attributeDict["end"].flatMap { Int($0) }
        cueLine.value = attributeDict["value"] ?? ""
        cueLine.agentId = attributeDict["agentId"]
        currentCueLine = cueLine
      }
    } else if elementName == "cue", currentCueLine != nil {
      currentCue = nil
      if let start = attributeDict["start"].flatMap({ Int($0) }),
         let byteStart = attributeDict["byteStart"].flatMap({ Int($0) }),
         let byteEnd = attributeDict["byteEnd"].flatMap({ Int($0) }) {
        var cue = LyricsCue()
        cue.start = start
        cue.end = attributeDict["end"].flatMap { Int($0) }
        cue.byteStart = byteStart
        cue.byteEnd = byteEnd
        cue.value = attributeDict["value"] ?? ""
        currentCue = cue
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "cue", var curCue = currentCue {
      // the cue text is the element content (XML) and keeps its trailing space
      if !buffer.isEmpty {
        curCue.value = buffer
      }
      currentCueLine?.cues.append(curCue)
      currentCue = nil
    } else if elementName == "cueLine", let curCueLine = currentCueLine {
      structuredLyrics?.cueLines.append(curCueLine)
      currentCueLine = nil
    } else if elementName == "line" || elementName == "value", var curLine = currentLine {
      curLine.value = buffer
      lines?.append(curLine)
      currentLine = nil
    } else if elementName == "structuredLyrics", var curStructuredLyrics = structuredLyrics {
      if let curLines = lines {
        curStructuredLyrics.line = curLines
      }
      lyricsList?.lyrics.append(curStructuredLyrics)
      structuredLyrics = nil
      lines = nil
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
