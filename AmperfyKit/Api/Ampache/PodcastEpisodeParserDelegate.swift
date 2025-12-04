//
//  PodcastEpisodeParserDelegate.swift
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

class PodcastEpisodeParserDelegate: PlayableParserDelegate {
  var podcast: Podcast
  var episodeBuffer: PodcastEpisode?
  var parsedEpisodes = [PodcastEpisode]()

  init(
    performanceMonitor: ThreadPerformanceMonitor,
    podcast: Podcast,
    prefetch: LibraryStorage.PrefetchElementContainer,
    account: Account,
    library: LibraryStorage
  ) {
    self.podcast = podcast
    super.init(
      performanceMonitor: performanceMonitor,
      prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
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

    switch elementName {
    case "podcast_episode":
      guard let episodeId = attributeDict["id"] else {
        os_log("Found podcast episode with no id", log: log, type: .error)
        return
      }
      if let prefetchedEpisode = prefetch.prefetchedPodcastEpisodeDict[episodeId] {
        episodeBuffer = prefetchedEpisode
      } else {
        episodeBuffer = library.createPodcastEpisode(account: account)
        episodeBuffer?.id = episodeId
        prefetch.prefetchedPodcastEpisodeDict[episodeId] = episodeBuffer
      }
      playableBuffer = episodeBuffer
      episodeBuffer?.podcast = podcast
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
    case "description":
      episodeBuffer?.depictionRawParsed = buffer
    case "pubdate":
      if buffer.contains("/") { // "3/27/21, 3:30 AM"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M-d-yy, h:mm a"
        dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
        episodeBuffer?.publishDate = dateFormatter
          .date(from: buffer) ?? Date(timeIntervalSince1970: TimeInterval())
      } else if buffer.count >= 21 { // "2011-02-03T14:46:43"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
        let dateWithoutTimeZoneString = String(buffer[..<buffer.index(
          buffer.startIndex,
          offsetBy: 19
        )])
        episodeBuffer?.publishDate = dateFormatter
          .date(from: dateWithoutTimeZoneString) ?? Date(timeIntervalSince1970: TimeInterval())
      } else {
        os_log(
          "Pubdate <%s> could not be parsed of podcast episode",
          log: log,
          type: .error,
          buffer
        )
      }
    case "state":
      episodeBuffer?.podcastStatus = PodcastEpisodeRemoteStatus.create(from: buffer)
    case "filelength":
      episodeBuffer?.remoteDuration = buffer.asDurationInSeconds ?? 0
    case "filesize":
      episodeBuffer?.size = buffer.asByteCount ?? 0
    case "art":
      episodeBuffer?.artwork = parseArtwork(urlString: buffer)
    case "podcast_episode":
      parsedCount += 1
      resetPlayableBuffer()
      episodeBuffer?.rating = rating
      rating = 0
      if let episode = episodeBuffer {
        parsedEpisodes.append(episode)
      }
      episodeBuffer = nil
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
