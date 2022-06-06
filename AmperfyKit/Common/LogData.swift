import Foundation
import UIKit

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
        serverInfo.apiType = amperfyData.backendProxy.selectedApi.description
        serverInfo.isAuthenticated = amperfyData.backendProxy.isAuthenticated()
        serverInfo.apiVersion = amperfyData.backendProxy.serverApiVersion
        logData.serverInfo = serverInfo
        
        logData.libraryInfo = amperfyData.library.getInfo()
        logData.libraryInfo?.version = amperfyData.persistentStorage.librarySyncVersion.description
        
        var playerInfo = PlayerInfo()
        playerInfo.isPlaying = amperfyData.player.isPlaying
        playerInfo.repeatType = amperfyData.player.repeatMode.description
        playerInfo.isShuffle = amperfyData.player.isShuffle
        playerInfo.songIndex = amperfyData.player.currentlyPlaying != nil ? 0 : -99
        playerInfo.playlistItemCount = amperfyData.player.prevQueue.count + amperfyData.player.nextQueue.count + 1
        logData.playerInfo = playerInfo
        
        var userSettings = UserSettings()
        let settings = amperfyData.persistentStorage.settings
        userSettings.swipeLeadingActions = settings.swipeActionSettings.leading.compactMap{ $0.displayName }
        userSettings.swipeTrailingActions = settings.swipeActionSettings.trailing.compactMap{ $0.displayName }
        userSettings.playerDisplayStyle = settings.playerDisplayStyle.description
        userSettings.isOfflineMode = settings.isOfflineMode
        logData.userSettings = userSettings
        
        let allUserStatistics = amperfyData.library.getAllUserStatistics()
        logData.userStatistics = allUserStatistics.compactMap{ $0.createLogInfo() }
        
        var eventInfo = EventInfo()
        let eventLogs = amperfyData.library.getLogEntries()
        eventInfo.totalEventCount = eventLogs.count
        eventInfo.events = Array(eventLogs.prefix(Self.latestEventsCount))
        eventInfo.attachedEventCount = eventInfo.events?.count ?? 0
        logData.eventInfo = eventInfo
        
        return logData
    }

}

public struct BasicInfo: Encodable {
    public var date: Date = Date()
    public var appName: String?
    public var appVersion: String?
    public var appBuildNumber: String?
}

public struct DeviceInfo: Encodable {
    public var device: String?
    public var iOSVersion: String?
    public var totalDiskCapacity: String?
    public var availableDiskCapacity: String?
}

public struct ServerInfo: Encodable {
    public var apiType: String?
    public var apiVersion: String?
    public var isAuthenticated: Bool?
}

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
    public var syncWaveCount: Int?
    public var artworkCount: Int?
    public var cachedSongSize: String?
    public var version: String?
}

public struct PlayerInfo: Encodable {
    public var isPlaying: Bool?
    public var repeatType: String?
    public var isShuffle: Bool?
    public var songIndex: Int?
    public var playlistItemCount: Int?
}

public struct UserSettings: Encodable {
    public var swipeLeadingActions: [String]?
    public var swipeTrailingActions: [String]?
    public var playerDisplayStyle: String?
    public var isOfflineMode: Bool?
}

public struct EventInfo: Encodable {
    public var totalEventCount: Int?
    public var attachedEventCount: Int?
    public var events: [LogEntry]?
}
