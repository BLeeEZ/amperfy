//
//  LogData.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.05.21.
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
import UIKit

// MARK: - LogData

public struct LogData: Encodable {
  public var basicInfo: BasicInfo?
  public var deviceInfo: DeviceInfo?
  public var serverInfo: ServerInfo?
  public var playerInfo: PlayerInfo?
  public var libraryInfo: LibraryInfo?
  public var userSettings: UserSettings?
  public var userStatistics: [UserStatisticsOverview]?
  public var eventInfo: EventInfo?

  static let latestEventsCount = 30

  @MainActor
  public static func collectInformation(amperfyData: AmperKit) -> LogData {
    var logData = LogData()

    var basicInfo = BasicInfo()
    basicInfo.appName = "Amperfy"
    basicInfo.appVersion = AmperKit.version
    basicInfo.appBuildNumber = AmperKit.buildNumber
    logData.basicInfo = basicInfo

    var deviceInfo = DeviceInfo()
    let currentDevice = UIDevice.current
    deviceInfo.device = currentDevice.model
    deviceInfo.iOSVersion = currentDevice.systemVersion
    deviceInfo.totalDiskCapacity = currentDevice.totalDiskCapacityInByte?.asByteString
    deviceInfo.availableDiskCapacity = currentDevice.availableDiskCapacityInByte?.asByteString
    logData.deviceInfo = deviceInfo

    var serverInfo = ServerInfo()
    serverInfo.apiType = amperfyData.backendApi.selectedApi.description
    serverInfo.apiVersion = amperfyData.backendApi.serverApiVersion
    logData.serverInfo = serverInfo

    logData.libraryInfo = amperfyData.storage.main.library.getInfo()
    logData.libraryInfo?.version = amperfyData.storage.librarySyncVersion.description

    var playerInfo = PlayerInfo()
    playerInfo.isPlaying = amperfyData.player.isPlaying
    playerInfo.repeatType = amperfyData.player.repeatMode.description
    playerInfo.isShuffle = amperfyData.player.isShuffle
    playerInfo.songIndex = amperfyData.player.currentlyPlaying != nil ? 0 : -99
    playerInfo.playlistItemCount = amperfyData.player.prevQueueCount + amperfyData.player
      .nextQueueCount + 1
    logData.playerInfo = playerInfo

    var userSettings = UserSettings()
    let settings = amperfyData.storage.settings
    userSettings.swipeLeadingActions = settings.swipeActionSettings.leading
      .compactMap { $0.displayName }
    userSettings.swipeTrailingActions = settings.swipeActionSettings.trailing
      .compactMap { $0.displayName }
    userSettings.playerDisplayStyle = settings.playerDisplayStyle.description
    userSettings.isOfflineMode = settings.isOfflineMode
    logData.userSettings = userSettings

    let allUserStatistics = amperfyData.storage.main.library.getAllUserStatistics()
    logData.userStatistics = allUserStatistics.compactMap { $0.createLogInfo() }

    var eventInfo = EventInfo()
    let eventLogs = amperfyData.storage.main.library.getLogEntries()
    eventInfo.totalEventCount = eventLogs.count
    eventInfo.events = Array(eventLogs.prefix(Self.latestEventsCount))
    eventInfo.attachedEventCount = eventInfo.events?.count ?? 0
    logData.eventInfo = eventInfo

    return logData
  }
}

// MARK: - BasicInfo

public struct BasicInfo: Encodable {
  public var date: Date = .init()
  public var appName: String?
  public var appVersion: String?
  public var appBuildNumber: String?
}

// MARK: - DeviceInfo

public struct DeviceInfo: Encodable {
  public var device: String?
  public var iOSVersion: String?
  public var totalDiskCapacity: String?
  public var availableDiskCapacity: String?
}

// MARK: - ServerInfo

public struct ServerInfo: Encodable {
  public var apiType: String?
  public var apiVersion: String?
}

// MARK: - LibraryInfo

public struct LibraryInfo: Encodable {
  public var genreCount: Int?
  public var artistCount: Int?
  public var albumCount: Int?
  public var songCount: Int?
  public var cachedSongCount: Int?
  public var playlistCount: Int?
  public var musicFolderCount: Int?
  public var directoryCount: Int?
  public var podcastCount: Int?
  public var podcastEpisodeCount: Int?
  public var artworkCount: Int?
  public var cachedSongSize: String?
  public var version: String?
}

// MARK: - PlayerInfo

public struct PlayerInfo: Encodable {
  public var isPlaying: Bool?
  public var repeatType: String?
  public var isShuffle: Bool?
  public var songIndex: Int?
  public var playlistItemCount: Int?
}

// MARK: - UserSettings

public struct UserSettings: Encodable {
  public var swipeLeadingActions: [String]?
  public var swipeTrailingActions: [String]?
  public var playerDisplayStyle: String?
  public var isOfflineMode: Bool?
}

// MARK: - EventInfo

public struct EventInfo: Encodable {
  public var totalEventCount: Int?
  public var attachedEventCount: Int?
  public var events: [LogEntry]?
}
