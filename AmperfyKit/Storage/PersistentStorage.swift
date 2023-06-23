//
//  PersistentStorage.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import CoreData
import PromiseKit

public enum ArtworkDownloadSetting: Int, CaseIterable {
    case updateOncePerSession = 0
    case onlyOnce = 1
    case never = 2
    
    static let defaultValue: ArtworkDownloadSetting = .onlyOnce
    
    public var description: String {
        switch self {
        case .updateOncePerSession:
            return "Download once per session (change detection)"
        case .onlyOnce:
            return "Download only once"
        case .never:
            return "Never"
        }
    }
}

public enum ArtworkDisplayPreference: Int, CaseIterable {
    case id3TagOnly = 0
    case serverArtworkOnly = 1
    case preferServerArtwork = 2
    case preferId3Tag = 3
    
    static let defaultValue: ArtworkDisplayPreference = .preferId3Tag
    
    public var description: String {
        switch self {
        case .id3TagOnly:
            return "Only ID3 tag artworks"
        case .serverArtworkOnly:
            return "Only server artworks"
        case .preferServerArtwork:
            return "Prefer server artwork over ID3 tag"
        case .preferId3Tag:
            return "Prefer ID3 tag over server artwork"
        }
    }
}

public class CoreDataCompanion {
    public let context: NSManagedObjectContext
    public let library: LibraryStorage
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.library = LibraryStorage(context: context)
    }
    
    public func saveContext() {
        library.saveContext()
    }
}

public class AsyncCoreDataAccessWrapper {
    let persistentContainer: NSPersistentContainer
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    public func perform(body: @escaping (_ asyncCompanion: CoreDataCompanion) throws -> Void) -> Promise<Void> {
        return Promise<Void> { seal in
            self.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let asyncCompanion = CoreDataCompanion(context: context)
                do {
                    try body(asyncCompanion)
                } catch {
                    return seal.reject(error)
                }
                library.saveContext()
                seal.fulfill(Void())
            }
        }
    }
}

public class PersistentStorage {

    private enum UserDefaultsKey: String {
        case ServerUrl = "serverUrl"
        case AlternativeServerUrls = "alternativeServerUrls"
        case Username = "username"
        case Password = "password"
        case BackendApi = "backendApi"
        case LibraryIsSynced = "libraryIsSynced"
        case ArtworkDownloadSetting = "artworkDownloadSetting"
        case ArtworkDisplayPreference = "artworkDisplayPreference"
        case SleepTimerInterval = "sleepTimerInterval"
        
        case SongActionOnTab = "songActionOnTab"
        case LibraryDisplaySettings = "libraryDisplaySettings"
        case SwipeLeadingActionSettings = "swipeLeadingActionSettings"
        case SwipeTrailingActionSettings = "swipeTrailingActionSettings"
        case PlaylistsSortSetting = "playlistsSortSetting"
        case ArtistsSortSetting = "artistsSortSetting"
        case AlbumsSortSetting = "albumsSortSetting"
        case SongsSortSetting = "songsSortSetting"
        case PodcastsShowSetting = "podcastsShowSetting"
        case PlayerDisplayStyle = "playerDisplayStyle"
        case IsOfflineMode = "isOfflineMode"
        case IsAutoDownloadLatestSongsActive = "isAutoDownloadLatestSongsActive"
        case IsAutoDownloadLatestPodcastEpisodesActive = "isAutoDownloadLatestPodcastEpisodesActive"
        case LibrarySyncVersion = "librarySyncVersion"
        
        case LibrarySyncInfoReadByUser = "librarySyncInfoReadByUser"
        
        case CacheLimit = "cacheLimitInBytes"
    }
    
    private var coreDataManager: CoreDataManagable
    
    init(coreDataManager: CoreDataManagable) {
        self.coreDataManager = coreDataManager
    }
    
    public class Settings {
        public var artworkDownloadSetting: ArtworkDownloadSetting {
            get {
                let artworkDownloadSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) as? Int ?? ArtworkDownloadSetting.defaultValue.rawValue
                return ArtworkDownloadSetting(rawValue: artworkDownloadSettingRaw) ?? ArtworkDownloadSetting.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) }
        }
        
        public var artworkDisplayPreference: ArtworkDisplayPreference {
            get {
                let artworkDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) as? Int ?? ArtworkDisplayPreference.defaultValue.rawValue
                return ArtworkDisplayPreference(rawValue: artworkDisplayStyleRaw) ?? ArtworkDisplayPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) }
        }
        
        public var sleepTimerInterval: Int {
            get {
                return UserDefaults.standard.object(forKey: UserDefaultsKey.SleepTimerInterval.rawValue) as? Int ?? 0
            }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.SleepTimerInterval.rawValue) }
        }
        
        public var cacheLimit: Int {
            get {
                return UserDefaults.standard.object(forKey: UserDefaultsKey.CacheLimit.rawValue) as? Int ?? 0
            }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.CacheLimit.rawValue) }
        }
        
        public var playlistsSortSetting: PlaylistSortType {
            get {
                let playlistsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) as? Int ?? PlaylistSortType.defaultValue.rawValue
                return PlaylistSortType(rawValue: playlistsSortSettingRaw) ?? PlaylistSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) }
        }
        
        public var artistsSortSetting: ElementSortType {
            get {
                let artistsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtistsSortSetting.rawValue) as? Int ?? ElementSortType.defaultValue.rawValue
                return ElementSortType(rawValue: artistsSortSettingRaw) ?? ElementSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtistsSortSetting.rawValue) }
        }
        
        
        public var albumsSortSetting: AlbumElementSortType {
            get {
                let albumsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.AlbumsSortSetting.rawValue) as? Int ?? AlbumElementSortType.defaultValue.rawValue
                return AlbumElementSortType(rawValue: albumsSortSettingRaw) ?? AlbumElementSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.AlbumsSortSetting.rawValue) }
        }
        
        public var songsSortSetting: ElementSortType {
            get {
                let songsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SongsSortSetting.rawValue) as? Int ?? ElementSortType.defaultValue.rawValue
                return ElementSortType(rawValue: songsSortSettingRaw) ?? ElementSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.SongsSortSetting.rawValue) }
        }
        
        public var swipeActionSettings: SwipeActionSettings {
            get {
                guard let swipeLeadingActionsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue) as? [Int],
                    let swipeTrailingActionsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue) as? [Int]
                else {
                    return SwipeActionSettings.defaultSettings
                }
                let swipeLeadingActions = swipeLeadingActionsRaw.compactMap{ SwipeActionType(rawValue: $0) }
                let swipeTrailingActions = swipeTrailingActionsRaw.compactMap{ SwipeActionType(rawValue: $0) }
                return SwipeActionSettings(leading: swipeLeadingActions, trailing: swipeTrailingActions)
            }
            set {
                UserDefaults.standard.set(newValue.leading.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue)
                UserDefaults.standard.set(newValue.trailing.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue)
            }
        }
        
        public var libraryDisplaySettings: LibraryDisplaySettings {
            get {
                guard let libraryDisplaySettingsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue) as? [Int]
                else {
                    return LibraryDisplaySettings.defaultSettings
                }
                let libraryDisplaySettings = libraryDisplaySettingsRaw.compactMap{ LibraryDisplayType(rawValue: $0) }
                return LibraryDisplaySettings(inUse: libraryDisplaySettings)
            }
            set {
                UserDefaults.standard.set(newValue.inUse.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue)
            }
        }
        
        public var podcastsShowSetting: PodcastsShowType {
            get {
                let podcastSortRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) as? Int ?? PodcastsShowType.defaultValue.rawValue
                return PodcastsShowType(rawValue: podcastSortRaw) ?? PodcastsShowType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) }
        }
        
        public var playerDisplayStyle: PlayerDisplayStyle {
            get {
                let playerDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) as? Int ?? PlayerDisplayStyle.defaultValue.rawValue
                return PlayerDisplayStyle(rawValue: playerDisplayStyleRaw) ?? PlayerDisplayStyle.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) }
        }
        
        public var isOfflineMode: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsOfflineMode.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsOfflineMode.rawValue) }
        }
        
        public var isAutoDownloadLatestSongsActive: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue) }
        }
        
        public var isAutoDownloadLatestPodcastEpisodesActive: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive.rawValue) }
        }
        
        public var isOnlineMode: Bool {
            return !isOfflineMode
        }
    }
    
    public var settings = Settings()

    public var loginCredentials: LoginCredentials? {
        get {
            if  let serverUrl = UserDefaults.standard.object(forKey: UserDefaultsKey.ServerUrl.rawValue) as? String,
                let username = UserDefaults.standard.object(forKey: UserDefaultsKey.Username.rawValue) as? String,
                let passwordHash = UserDefaults.standard.object(forKey: UserDefaultsKey.Password.rawValue) as? String,
                let backendApiRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.BackendApi.rawValue) as? Int,
                let backendApi = BackenApiType(rawValue: backendApiRaw) {
                    return LoginCredentials(serverUrl: serverUrl, username: username, password: passwordHash, backendApi: backendApi)
            }
            return nil
        }
        set {
            if let newCredentials = newValue {
                UserDefaults.standard.set(newCredentials.serverUrl, forKey: UserDefaultsKey.ServerUrl.rawValue)
                UserDefaults.standard.set(newCredentials.username, forKey: UserDefaultsKey.Username.rawValue)
                UserDefaults.standard.set(newCredentials.password, forKey: UserDefaultsKey.Password.rawValue)
                UserDefaults.standard.set(newCredentials.backendApi.rawValue, forKey: UserDefaultsKey.BackendApi.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.ServerUrl.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Username.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Password.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.BackendApi.rawValue)
            }
        }
    }
    
    public var alternativeServerURLs: [String] {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.AlternativeServerUrls.rawValue) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlternativeServerUrls.rawValue)
        }
    }
    
    public var isLibrarySyncInfoReadByUser: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) }
    }

    public var isLibrarySynced: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryIsSynced.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibraryIsSynced.rawValue) }
    }
    
    public var librarySyncVersion: LibrarySyncVersion {
        get {
            if let raw = UserDefaults.standard.object(forKey: UserDefaultsKey.LibrarySyncVersion.rawValue) as? Int,
               let version = LibrarySyncVersion(rawValue: raw) {
                    return version
            }
            return LibrarySyncVersion.v6
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.LibrarySyncVersion.rawValue)
        }
    }
    
    public lazy var main: CoreDataCompanion = {
        return CoreDataCompanion(context: coreDataManager.context)
    }()
    
    public lazy var async: AsyncCoreDataAccessWrapper = {
        return AsyncCoreDataAccessWrapper(persistentContainer: coreDataManager.persistentContainer)
    }()

}

// MARK: - Core Data stack

protocol CoreDataManagable {
    var persistentContainer: NSPersistentContainer { get }
    var context: NSManagedObjectContext { get }
}

public class CoreDataPersistentManager: CoreDataManagable {

    static var managedObjectModel: NSManagedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Amperfy", managedObjectModel: CoreDataPersistentManager.managedObjectModel)
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        description?.type = NSSQLiteStoreType
        
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            fatalError("persistentContainer was not set up properly")
        }
        
        let migrator = CoreDataMigrator()
        if migrator.requiresMigration(at: storeURL, toVersion: CoreDataMigrationVersion.current) {
            migrator.migrateStore(at: storeURL, toVersion: CoreDataMigrationVersion.current)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        return container
    }()
    
    lazy var context: NSManagedObjectContext = {
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        return persistentContainer.viewContext
    }()

}
