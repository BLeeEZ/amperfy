//
//  SsPodcastEpisodeParserDelegate.swift
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

class SsPodcastEpisodeParserDelegate: SsPlayableParserDelegate {
  var podcast: Podcast?
  var episodeBuffer: PodcastEpisode?
  var parsedEpisodes = [PodcastEpisode]()

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    podcast: Podcast?,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.podcast = podcast
    super.init(
      performanceMonitor: performanceMonitor,
      prefetch: prefetch,
      account: account,
      library: library
    )
  }

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    if elementName == "episode" {
      guard let episodeId = attributeDict["id"] else {
        os_log("Found podcast episode with no id", log: log, type: .error)
        return
      }
      if let prefetchedEpisode = prefetch.prefetchedPodcastEpisodeDict[episodeId] {
        episodeBuffer = prefetchedEpisode
      } else {
        episodeBuffer = library.createPodcastEpisode(account: account)
        prefetch.prefetchedPodcastEpisodeDict[episodeId] = episodeBuffer
        episodeBuffer?.id = episodeId
      }
      playableBuffer = episodeBuffer
      if let podcast = podcast {
        episodeBuffer?.podcast = podcast
      } else if let channelId = attributeDict["channelId"] {
        let curPodcast = prefetch.prefetchedPodcastDict[channelId]
        episodeBuffer?.podcast = curPodcast
      }

      if let description = attributeDict["description"] {
        episodeBuffer?.depictionRawParsed = description
      }
      if let publishDate = attributeDict["publishDate"], publishDate.count >= 19 {
        // "2011-02-03T14:46:43"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
        let dateWithoutTimeZoneString = String(publishDate[..<publishDate.index(
          publishDate.startIndex,
          offsetBy: 19
        )])
        episodeBuffer?.publishDate = dateFormatter
          .date(from: dateWithoutTimeZoneString) ?? Date(timeIntervalSince1970: TimeInterval())
      }
      if let status = attributeDict["status"] {
        episodeBuffer?.podcastStatus = PodcastEpisodeRemoteStatus.create(from: status)
      }
      if let streamId = attributeDict["streamId"] {
        episodeBuffer?.streamId = streamId
      }
      if let coverArtId = attributeDict["coverArt"] {
        episodeBuffer?.artwork = parseArtwork(id: coverArtId)
      }
    }

    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )

    if elementName == "episode", let episode = episodeBuffer {
      parsedCount += 1
      resetPlayableBuffer()
      parsedEpisodes.append(episode)
      episodeBuffer = nil
    }
  }

  override public func performPostParseOperations() {
    for episode in parsedEpisodes {
      // html2String is CPU intensive do it only one when title/depiction is not set yet
      if episode.playableManagedObject.title == nil {
        episode.title = episode.titleRawParsed.html2String
      }
      if episode.depiction == nil {
        episode.depiction = episode.depictionRawParsed?.html2String
      }
    }
  }
}
