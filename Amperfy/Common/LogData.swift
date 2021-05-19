import Foundation

public struct LogData: Codable {
    
    public var basicInfo: BasicInfo?
    public var serverInfo: ServerInfo?
    public var libraryInfo: LibraryInfo?
    
    static func collectInformation(appDelegate: AppDelegate) -> LogData {
        var logData = LogData()
        
        var basicInfo = BasicInfo()
        basicInfo.appName = "Amperfy"
        basicInfo.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        basicInfo.appBuildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        logData.basicInfo = basicInfo
        
        var serverInfo = ServerInfo()
        serverInfo.apiType = appDelegate.backendProxy.selectedApi.description
        serverInfo.apiVersion = appDelegate.backendProxy.serverApiVersion
        logData.serverInfo = serverInfo
        
        logData.libraryInfo = appDelegate.persistentLibraryStorage.getInfo()
        
        return logData
    }

}

public struct BasicInfo: Codable {
    public var appName: String?
    public var appVersion: String?
    public var appBuildNumber: String?
}

public struct ServerInfo: Codable {
    public var apiType: String?
    public var apiVersion: String?
}

public struct LibraryInfo: Codable {
    public var artistCount: Int?
    public var albumCount: Int?
    public var songCount: Int?
    public var cachedSongCount: Int?
    public var playlistCount: Int?
    public var cachedSongSizeInKB: Int?
}
