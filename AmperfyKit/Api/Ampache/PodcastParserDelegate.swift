//
//  PodcastParserDelegate.swift
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

class PodcastParserDelegate: AmpacheXmlLibParser {
  var parsedPodcasts = Set<Podcast>()
  private var podcastBuffer: Podcast?
  var rating: Int = 0

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
    case "podcast":
      guard let podcastId = attributeDict["id"] else {
        os_log("Error: Podcast could not be parsed -> id is not given", log: log, type: .error)
        return
      }
      if let prefetchedPodcast = prefetch.prefetchedPodcastDict[podcastId] {
        podcastBuffer = prefetchedPodcast
      } else {
        podcastBuffer = library.createPodcast(account: account)
        podcastBuffer?.id = podcastId
        prefetch.prefetchedPodcastDict[podcastId] = podcastBuffer
      }
      podcastBuffer?.remoteStatus = .available
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
    case "name":
      podcastBuffer?.titleRawParsed = buffer
    case "description":
      podcastBuffer?.depictionRawParsed = buffer
    case "rating":
      rating = Int(buffer) ?? 0
    case "art":
      podcastBuffer?.artwork = parseArtwork(urlString: buffer)
    case "podcast":
      podcastBuffer?.rating = rating
      rating = 0
      if let parsedPodcast = podcastBuffer {
        parsedPodcasts.insert(parsedPodcast)
      }
      podcastBuffer = nil
      parseNotifier?.notifyParsedObject(ofType: .podcast)
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
