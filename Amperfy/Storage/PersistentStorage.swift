import Foundation
import CoreData

enum ArtworkDownloadSetting: Int, CaseIterable {
    case updateOncePerSession = 0
    case onlyOnce = 1
    case never = 2
    
    static let defaultValue: ArtworkDownloadSetting = .updateOncePerSession
    
    var description: String {
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

enum ArtworkDisplayPreference: Int, CaseIterable {
    case id3TagOnly = 0
    case serverArtworkOnly = 1
    case preferServerArtwork = 2
    case preferId3Tag = 3
    
    static let defaultValue: ArtworkDisplayPreference = .preferId3Tag
    
    var description: String {
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

class PersistentStorage {

    private enum UserDefaultsKey: String {
        case ServerUrl = "serverUrl"
        case AlternativeServerUrls = "alternativeServerUrls"
        case Username = "username"
        case Password = "password"
        case BackendApi = "backendApi"
        case LibraryIsSynced = "libraryIsSynced"
        case ArtworkDownloadSetting = "artworkDownloadSetting"
        case ArtworkDisplayPreference = "artworkDisplayPreference"
        
        case SongActionOnTab = "songActionOnTab"
        case SwipeLeadingActionSettings = "swipeLeadingActionSettings"
        case SwipeTrailingActionSettings = "swipeTrailingActionSettings"
        case PlaylistsSortSetting = "playlistsSortSetting"
        case PodcastsShowSetting = "podcastsShowSetting"
        case PlayerDisplayStyle = "playerDisplayStyle"
        case IsOfflineMode = "isOfflineMode"
        case LibrarySyncVersion = "librarySyncVersion"
        
        case LibrarySyncInfoReadByUser = "librarySyncInfoReadByUser"
    }
    
    class Settings {
        var artworkDownloadSetting: ArtworkDownloadSetting {
            get {
                let artworkDownloadSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) as? Int ?? ArtworkDownloadSetting.defaultValue.rawValue
                return ArtworkDownloadSetting(rawValue: artworkDownloadSettingRaw) ?? ArtworkDownloadSetting.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) }
        }
        
        var artworkDisplayPreference: ArtworkDisplayPreference {
            get {
                let artworkDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) as? Int ?? ArtworkDisplayPreference.defaultValue.rawValue
                return ArtworkDisplayPreference(rawValue: artworkDisplayStyleRaw) ?? ArtworkDisplayPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) }
        }
        
        var playlistsSortSetting: PlaylistSortType {
            get {
                let playlistsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) as? Int ?? PlaylistSortType.defaultValue.rawValue
                return PlaylistSortType(rawValue: playlistsSortSettingRaw) ?? PlaylistSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) }
        }
        
        var swipeActionSettings: SwipeActionSettings {
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
        
        var podcastsShowSetting: PodcastsShowType {
            get {
                let podcastSortRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) as? Int ?? PodcastsShowType.defaultValue.rawValue
                return PodcastsShowType(rawValue: podcastSortRaw) ?? PodcastsShowType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) }
        }
        
        var playerDisplayStyle: PlayerDisplayStyle {
            get {
                let playerDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) as? Int ?? PlayerDisplayStyle.defaultValue.rawValue
                return PlayerDisplayStyle(rawValue: playerDisplayStyleRaw) ?? PlayerDisplayStyle.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) }
        }
        
        var isOfflineMode: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsOfflineMode.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsOfflineMode.rawValue) }
        }
        var isOnlineMode: Bool {
            return !isOfflineMode
        }
    }
    
    var settings = Settings()

    var loginCredentials: LoginCredentials? {
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
    
    var alternativeServerURLs: [String] {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.AlternativeServerUrls.rawValue) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlternativeServerUrls.rawValue)
        }
    }
    
    var isLibrarySyncInfoReadByUser: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) }
    }

    var isLibrarySynced: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryIsSynced.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibraryIsSynced.rawValue) }
    }
    
    var librarySyncVersion: LibrarySyncVersion {
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

    
    // MARK: - Core Data stack
    
    static var managedObjectModel: NSManagedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Amperfy", managedObjectModel: PersistentStorage.managedObjectModel)
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
