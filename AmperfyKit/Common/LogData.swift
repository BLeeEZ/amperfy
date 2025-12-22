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
  public var playerInfo: PlayerInfo?
  public var libraryInfo: LibraryInfo?
  public var userSettings: UserSettingsLog?
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

    logData.libraryInfo = LibraryInfo()
    logData.libraryInfo?.version = amperfyData.storage.settings.app.librarySyncVersion.description
    let allAccountInfos = amperfyData.storage.settings.accounts.allAccounts
    for accountInfo in allAccountInfos {
      let account = amperfyData.storage.main.library.getAccount(info: accountInfo)
      let accountLibraryInfo = amperfyData.storage.main.library.getInfo(account: account)
      logData.libraryInfo?.accounts?.append(accountLibraryInfo)
    }

    var playerInfo = PlayerInfo()
    playerInfo.isPlaying = amperfyData.player.isPlaying
    playerInfo.repeatType = amperfyData.player.repeatMode.description
    playerInfo.isShuffle = amperfyData.player.isShuffle
    playerInfo.songIndex = amperfyData.player.currentlyPlaying != nil ? 0 : -99
    playerInfo.playlistItemCount = amperfyData.player.prevQueueCount + amperfyData.player
      .nextQueueCount + 1
    logData.playerInfo = playerInfo

    var userSettings = UserSettingsLog()
    let settings = amperfyData.storage.settings
    userSettings.swipeLeadingActions = settings.user.swipeActionSettings.leading
      .compactMap { $0.displayName }
    userSettings.swipeTrailingActions = settings.user.swipeActionSettings.trailing
      .compactMap { $0.displayName }
    userSettings.playerDisplayStyle = settings.user.playerDisplayStyle.description
    userSettings.isOfflineMode = settings.user.isOfflineMode
    logData.userSettings = userSettings

    let allUserStatistics = amperfyData.storage.main.library.getAllUserStatistics()
    logData.userStatistics = allUserStatistics.compactMap { $0.createLogInfo() }

    var eventInfo = EventInfo()
    let eventLogs = amperfyData.storage.main.library.getAllLogEntries()
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

// MARK: - LibraryInfo

public struct LibraryInfo: Encodable {
  public var version: String?
  public var accounts: [AccountLibraryInfo]?
}

// MARK: - AccountLibraryInfo

public struct AccountLibraryInfo: Encodable {
  public var apiType: String?
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
  public var radioCount: Int?
  public var artworkCount: Int?
  public var cachedSongSize: String?
}

// MARK: - PlayerInfo

public struct PlayerInfo: Encodable {
  public var isPlaying: Bool?
  public var repeatType: String?
  public var isShuffle: Bool?
  public var songIndex: Int?
  public var playlistItemCount: Int?
}

// MARK: - UserSettingsLog

public struct UserSettingsLog: Encodable {
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
