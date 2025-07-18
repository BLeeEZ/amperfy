//
//  PlayableParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
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

class PlayableParserDelegate: AmpacheXmlLibParser {
  var playableBuffer: AbstractPlayable?
  var rating: Int = 0
  private var isCached = true
  private var duration: Int = 0
  var isCollectionCached: Bool {
    parsedCount > 0 ? isCached : false
  }

  var collectionDuration: Int {
    parsedCount > 0 ? duration : 0
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
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "title":
      if let episode = playableBuffer as? PodcastEpisode {
        episode.titleRawParsed = buffer
      } else {
        playableBuffer?.title = buffer
      }
    case "rating":
      rating = Int(buffer) ?? 0
    case "flag":
      let flag = Int(buffer) ?? 0
      playableBuffer?.isFavorite = flag == 1 ? true : false
    case "track":
      playableBuffer?.track = Int(buffer) ?? 0
    case "url":
      playableBuffer?.url = buffer
    case "year":
      playableBuffer?.year = Int(buffer) ?? 0
    case "time":
      playableBuffer?.remoteDuration = Int(buffer) ?? 0
    case "art":
      playableBuffer?.artwork = parseArtwork(urlString: buffer)
    case "size":
      playableBuffer?.size = Int(buffer) ?? 0
    case "bitrate":
      playableBuffer?.bitrate = Int(buffer) ?? 0
    case "mime":
      playableBuffer?.contentType = buffer
    case "disk":
      playableBuffer?.disk = buffer
    case "replaygain_album_gain":
      playableBuffer?.replayGainAlbumGain = Float(buffer) ?? 0.0
    case "replaygain_album_peak":
      playableBuffer?.replayGainAlbumPeak = Float(buffer) ?? 0.0
    case "replaygain_track_gain":
      playableBuffer?.replayGainTrackGain = Float(buffer) ?? 0.0
    case "replaygain_track_peak":
      playableBuffer?.replayGainTrackPeak = Float(buffer) ?? 0.0
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

  func resetPlayableBuffer() {
    if let playable = playableBuffer {
      isCached = isCached && playable.isCached
      duration += playable.duration
    }
    playableBuffer = nil
  }
}
