//
//  GenericXmlParser.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

import Foundation
import os.log

class GenericXmlParser: NSObject, XMLParserDelegate {
  static let debugPrint = false
  /// Background tasks that produce to much CPU load will be terminated by iOS:
  /// Event:               cpu usage
  /// Action taken:    Process killed
  /// CPU:                48 seconds cpu time over 51 seconds (93% cpu average), exceeding limit of 80% cpu over 60 seconds
  /// When big albums/playlists are requested by Amperfy the following happens:
  /// - The XML file gets generated on the server and will be send to Amperfy as answer. This process creates no/small CPU load
  /// - The response is parsed by an API XML Parser.
  /// Depending on the library size (songs need to be fetched from local database with lots of entries) and the response file size, the parsing process can take very long.
  /// The parse time will be monitored and after a certain threshold the ThreadPerformanceMonitor is asked if a slow down is requered.
  /// If the App is in Foreground now slow down is needed the CPU load can be 100% for any amount of time.
  /// If the App gets send to Background the callback returns true and the CPU will be send to slepp for a certain amount of time to reduce the CPU load.
  /// With this sleep aproach the sync process can go on even in background.
  static let activeTimeDurationNanoSec: UInt32 = 20_000_000 // 20 milliseconds
  static let sleepTimeDurationMicroSec: UInt32 = (4 * activeTimeDurationNanoSec) / 1000

  let log = OSLog(subsystem: "Amperfy", category: "Parser")
  let performanceMonitor: ThreadPerformanceMonitor
  var buffer = ""
  var parsedCount = 0
  var startTime: DispatchTime

  init(performanceMonitor: ThreadPerformanceMonitor) {
    self.performanceMonitor = performanceMonitor
    self.startTime = DispatchTime.now()
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    buffer.append(string)
  }

  func parseErrorOcurred(parser: XMLParser, error: NSError) {
    os_log("Error: %s", log: log, type: .error, error.localizedDescription)
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    buffer = ""
    if Self.debugPrint {
      os_log("<%s, %s>", log: log, type: .debug, elementName, attributeDict.description)
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if Self.debugPrint {
      if !buffer.isEmpty {
        os_log("%s", log: log, type: .debug, buffer)
      }
      os_log("</%s>", log: log, type: .debug, elementName)
    }
    buffer = ""
    let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    if elapsedTime > Self.activeTimeDurationNanoSec {
      if Self.debugPrint {
        os_log(
          "Parsing took longer then %f milliseconds",
          log: log,
          type: .debug,
          Double(Double(Self.activeTimeDurationNanoSec) / 1_000_000)
        )
      }
      if performanceMonitor.shouldSlowDownExecution {
        if Self.debugPrint {
          os_log(
            "Parsing took long: sleep for %f milliseconds to reduce CPU load",
            log: log,
            type: .debug,
            Double(Double(Self.sleepTimeDurationMicroSec) / 1_000)
          )
        }
        usleep(Self.sleepTimeDurationMicroSec)
      }
      startTime = DispatchTime.now()
    }
  }

  /// Some operations are not allowed to be performed during parsing
  /// This function needs to be called after parser.parse()
  /// override if required
  public func performPostParseOperations() {}
}
