//
//  AmpacheXmlParser.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.05.21.
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

import Foundation

// MARK: - AmpacheXmlParser

class AmpacheXmlParser: GenericXmlParser {
  var error: AmpacheResponseError?
  private var statusCode: Int = 0
  private var message = ""

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

    switch elementName {
    case "error":
      statusCode = Int(attributeDict["errorCode"] ?? "0") ?? 0
    default:
      break
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "errorMessage":
      message = buffer
    case "error":
      error = AmpacheResponseError(statusCode: statusCode, message: message)
    default:
      break
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}

// MARK: - AmpacheNotifiableXmlParser

class AmpacheNotifiableXmlParser: AmpacheXmlParser {
  var parseNotifier: ParsedObjectNotifiable?

  init(performanceMonitor: ThreadPerformanceMonitor, parseNotifier: ParsedObjectNotifiable? = nil) {
    self.parseNotifier = parseNotifier
    super.init(performanceMonitor: performanceMonitor)
  }
}

// MARK: - AmpacheXmlLibParser

class AmpacheXmlLibParser: AmpacheNotifiableXmlParser {
  var prefetch: LibraryStorage.PrefetchElementContainer
  var account: Account
  var library: LibraryStorage

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage,
    parseNotifier: ParsedObjectNotifiable? = nil
  ) {
    self.prefetch = prefetch
    self.account = account
    self.library = library
    super.init(performanceMonitor: performanceMonitor, parseNotifier: parseNotifier)
  }

  func parseArtwork(urlString: String) -> Artwork? {
    guard let artworkRemoteInfo = AmpacheXmlServerApi
      .extractArtworkInfoFromURL(urlString: urlString) else { return nil }
    if let prefetchedArtwork = prefetch.prefetchedArtworkDict[artworkRemoteInfo] {
      return prefetchedArtwork
    } else {
      let createdArtwork = library.createArtwork(account: account)
      prefetch.prefetchedArtworkDict[artworkRemoteInfo] = createdArtwork
      createdArtwork.remoteInfo = artworkRemoteInfo
      createdArtwork.status = .NotChecked
      return createdArtwork
    }
  }
}
