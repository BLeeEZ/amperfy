import Foundation
import UIKit

public struct LogData: Encodable {
    
    public var basicInfo: BasicInfo?
    public var deviceInfo: DeviceInfo?
    public var serverInfo: ServerInfo?
    public var playerInfo: PlayerInfo?
    public var libraryInfo: LibraryInfo?
    public var userSettings: UserSettings?
    public var eventInfo: EventInfo?
    
    static let latestEventsCount = 30
    
    static func collectInformation(appDelegate: AppDelegate) -> LogData {
        var logData = LogData()
        
        var basicInfo = BasicInfo()
        basicInfo.appName = "Amperfy"
        basicInfo.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        basicInfo.appBuildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        logData.basicInfo = basicInfo
        
        var deviceInfo = DeviceInfo()
        let currentDevice = UIDevice.current
        deviceInfo.device = currentDevice.name
        deviceInfo.iOSVersion = currentDevice.systemVersion
        deviceInfo.totalDiskCapacity = currentDevice.totalDiskCapacityInByte?.asByteString
        deviceInfo.availableDiskCapacity = currentDevice.availableDiskCapacityInByte?.asByteString
        logData.deviceInfo = deviceInfo
        
        var serverInfo = ServerInfo()
        serverInfo.apiType = appDelegate.backendProxy.selectedApi.description
        serverInfo.url = appDelegate.storage.getLoginCredentials()?.serverUrl ?? "-"
        serverInfo.isAuthenticated = appDelegate.backendProxy.isAuthenticated()
        serverInfo.apiVersion = appDelegate.backendProxy.serverApiVersion
        logData.serverInfo = serverInfo
        
        logData.libraryInfo = appDelegate.persistentLibraryStorage.getInfo()
        
        var playerInfo = PlayerInfo()
        playerInfo.playlistItemCount = appDelegate.player.playlist.items.count
        playerInfo.isPlaying = appDelegate.player.isPlaying
        playerInfo.repeatType = appDelegate.player.repeatMode.description
        playerInfo.isShuffle = appDelegate.player.isShuffle
        playerInfo.songIndex = appDelegate.player.currentlyPlaying?.index ?? -99
        playerInfo.playlistItemCount = appDelegate.player.playlist.items.count
        logData.playerInfo = playerInfo
        
        var userSettings = UserSettings()
        let settings = appDelegate.storage.getSettings()
        userSettings.songActionOnTab = settings.songActionOnTab.description
        userSettings.playerDisplayStyle = settings.playerDisplayStyle.description
        logData.userSettings = userSettings
        
        var eventInfo = EventInfo()
        let eventLogs = appDelegate.persistentLibraryStorage.getLogEntries()
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
    public var url: String?
    public var isAuthenticated: Bool?
}

public struct LibraryInfo: Encodable {
    public var genreCount: Int?
    public var artistCount: Int?
    public var albumCount: Int?
    public var songCount: Int?
    public var cachedSongCount: Int?
    public var playlistCount: Int?
    public var syncWaveCount: Int?
    public var artworkCount: Int?
    public var cachedSongSize: String?
}

public struct PlayerInfo: Encodable {
    public var isPlaying: Bool?
    public var repeatType: String?
    public var isShuffle: Bool?
    public var songIndex: Int?
    public var playlistItemCount: Int?
}

public struct UserSettings: Encodable {
    public var songActionOnTab: String?
    public var playerDisplayStyle: String?
}

public struct EventInfo: Encodable {
    public var totalEventCount: Int?
    public var attachedEventCount: Int?
    public var events: [LogEntry]?
}
