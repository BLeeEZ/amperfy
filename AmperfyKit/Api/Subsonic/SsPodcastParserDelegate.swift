//
//  SsPodcastParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.06.21.
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
import os.log
import UIKit

class SsPodcastParserDelegate: SsXmlLibWithArtworkParser {
  var parsedPodcasts: Set<Podcast>
  private var podcastBuffer: Podcast?

  override init(
    performanceMonitor: ThreadPerformanceMonitor,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage,
    parseNotifier: ParsedObjectNotifiable? = nil
  ) {
    self.parsedPodcasts = Set<Podcast>()
    super.init(
      performanceMonitor: performanceMonitor, prefetch: prefetch,
      account: account, library: library,
      parseNotifier: parseNotifier
    )
  }

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

    if elementName == "channel" {
      guard let podcastId = attributeDict["id"] else { return }
      guard let attributePodcastStatus = attributeDict["status"],
            attributePodcastStatus != "error" else { return }

      if let prefetchedPodcast = prefetch.prefetchedPodcastDict[podcastId] {
        podcastBuffer = prefetchedPodcast
      } else {
        podcastBuffer = library.createPodcast(account: account)
        prefetch.prefetchedPodcastDict[podcastId] = podcastBuffer
        podcastBuffer?.id = podcastId
      }
      podcastBuffer?.remoteStatus = .available

      if let attributePodcastTitle = attributeDict["title"] {
        podcastBuffer?.titleRawParsed = attributePodcastTitle
      }
      if let attributeDescription = attributeDict["description"] {
        podcastBuffer?.depictionRawParsed = attributeDescription
      }
      if let attributeCoverArt = attributeDict["coverArt"] {
        podcastBuffer?.artwork = parseArtwork(id: attributeCoverArt)
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "channel":
      parsedCount += 1
      if let parsedPodcast = podcastBuffer {
        parsedPodcasts.insert(parsedPodcast)
      }
      podcastBuffer = nil
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

  override public func performPostParseOperations() {
    for podcast in parsedPodcasts {
      podcast.title = podcast.titleRawParsed.html2String
      podcast.depiction = podcast.depictionRawParsed.html2String
    }
  }
}
