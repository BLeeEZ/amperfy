//
//  PodcastEpisode.swift
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
import UIKit

// MARK: - PodcastEpisodeRemoteStatus

public enum PodcastEpisodeRemoteStatus: Int {
  /*
   Subsonic:
   <xs:simpleType name="PodcastStatus">
       <xs:restriction base="xs:string">
           <xs:enumeration value="new"/>
           <xs:enumeration value="downloading"/>
           <xs:enumeration value="completed"/>
           <xs:enumeration value="error"/>
           <xs:enumeration value="deleted"/>
           <xs:enumeration value="skipped"/>
       </xs:restriction>
   </xs:simpleType>

   Ampache:
   pending -> mapped to downloading
   completed
   */
  case undefined = 0
  case new = 1
  case downloading = 2
  case completed = 3
  case error = 4
  case deleted = 5
  case skipped = 6

  public static func create(from text: String) -> PodcastEpisodeRemoteStatus {
    switch text {
    case "new": return .new
    case "downloading": return .downloading
    case "completed": return .completed
    case "error": return .error
    case "deleted": return .deleted
    case "skipped": return .skipped

    case "Pending": return .downloading
    case "Completed": return .completed
    default: return .undefined
    }
  }
}

// MARK: - PodcastEpisodeUserStatus

public enum PodcastEpisodeUserStatus {
  case syncingOnServer
  case availableOnServer
  case cached
  case deleted

  public var description: String {
    switch self {
    case .syncingOnServer: return "Server syncing"
    case .availableOnServer: return "Available"
    case .cached: return "Cached"
    case .deleted: return "Deleted on server"
    }
  }
}

// MARK: - PodcastEpisode

public class PodcastEpisode: AbstractPlayable {
  public let managedObject: PodcastEpisodeMO

  public init(managedObject: PodcastEpisodeMO) {
    self.managedObject = managedObject
    super.init(managedObject: managedObject)
  }

  override public var creatorName: String {
    podcast?.title ?? "Unknown Podcast"
  }

  public var titleRawParsed: String = "" // used by parser a temporary buffer
  public var depictionRawParsed: String? // used by parser a temporary buffer

  public var depiction: String? {
    get { managedObject.depiction }
    set {
      if managedObject.depiction != newValue { managedObject.depiction = newValue }
    }
  }

  public var publishDate: Date {
    get { managedObject.publishDate ?? Date() }
    set { if managedObject.publishDate != newValue { managedObject.publishDate = newValue } }
  }

  public var podcastStatus: PodcastEpisodeRemoteStatus {
    get { PodcastEpisodeRemoteStatus(rawValue: Int(managedObject.status)) ?? .undefined }
    set {
      if managedObject.status != newValue
        .rawValue { managedObject.status = Int16(newValue.rawValue) }
    }
  }

  public var userStatus: PodcastEpisodeUserStatus {
    if isCached {
      return .cached
    } else if podcastStatus == .completed {
      return .availableOnServer
    } else if podcastStatus == .deleted {
      return .deleted
    } else {
      return .syncingOnServer
    }
  }

  override public func isAvailableToUser() -> Bool {
    userStatus == .cached || userStatus == .availableOnServer
  }

  public var streamId: String? {
    get { managedObject.streamId }
    set { if managedObject.streamId != newValue { managedObject.streamId = newValue } }
  }

  public var remainingTimeInSec: Int? {
    guard playDuration > 0, playProgress > 0 else { return nil }
    return playDuration - playProgress
  }

  public var playProgressPercent: Float? {
    guard playDuration > 0, playProgress > 0 else { return nil }
    return Float(playProgress) / Float(playDuration)
  }

  public var podcast: Podcast? {
    get {
      guard let podcastMO = managedObject.podcast else { return nil }
      return Podcast(managedObject: podcastMO)
    }
    set {
      if managedObject.podcast != newValue?
        .managedObject { managedObject.podcast = newValue?.managedObject }
    }
  }

  public override func deleteCache() {
    podcast?.isCached = false
    for playlistItemMO in managedObject.playlistItems {
      if playlistItemMO.playlist.isCached {
        playlistItemMO.playlist.isCached = false
      }
    }
  }

  public var detailInfo: String {
    var info = title
    info += " ("
    let podcastName = podcast?.title ?? "-"
    info += "album: \(podcastName),"

    info += " id: \(id),"
    info += " track: \(track),"
    info += " year: \(year),"
    info += " remote duration: \(remoteDuration),"
    let diskInfo = disk ?? "-"
    info += " disk: \(diskInfo),"
    info += " size: \(size),"
    let contentTypeInfo = contentType ?? "-"
    info += " contentType: \(contentTypeInfo),"
    info += " bitrate: \(bitrate),"

    info += " description: \(depiction ?? "-")"
    info += " publishDate: \(publishDate.asIso8601String),"
    info += " podcastStatus: \(podcastStatus)"
    info += ")"
    return info
  }

  override public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if details.type == .long {
      infoContent.append("\(publishDate.asShortDayMonthString)")
      if !isAvailableToUser(), !isCached {
        infoContent.append("Not Available")
      } else if let remainingTime = remainingTimeInSec {
        infoContent.append("\(remainingTime.asDurationString) left")
      } else if duration > 0 {
        infoContent.append("\(duration.asDurationString)")
      }
      if details.isShowDetailedInfo {
        if bitrate > 0 {
          infoContent.append("Bitrate: \(bitrate)")
        }
        if isCached {
          if let contentType = contentType, let fileContentType = fileContentType,
             contentType != fileContentType {
            infoContent.append("Transcoded MIME Type: \(fileContentType)")
            infoContent.append("Original MIME Type: \(contentType)")
          } else if let contentType = contentType {
            infoContent.append("Cache MIME Type: \(contentType)")
          } else if let fileContentType = fileContentType {
            infoContent.append("Cache MIME Type: \(fileContentType)")
          }
        }
        infoContent.append("ID: \(!id.isEmpty ? id : "-")")
      }
    }
    return infoContent
  }
}

extension Array where Element: PodcastEpisode {
  public func sortByPublishDate() -> [Element] {
    sorted { $0.publishDate.compare($1.publishDate) == .orderedDescending }
  }
}
