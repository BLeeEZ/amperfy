import Foundation
import CoreData

class PersistentStorage {

    private enum UserDefaultsKey: String {
        case ServerUrl = "serverUrl"
        case Username = "username"
        case Password = "password"
        case BackendApi = "backendApi"
        case LibraryIsSynced = "libraryIsSynced"
        
        case SongActionOnTab = "songActionOnTab"
        case PlayerDisplayStyle = "playerDisplayStyle"
        case LibrarySyncVersion = "librarySyncVersion"
        
        case SongsSyncInfoReadByUser = "SongsSyncInfoReadByUser"
    }

    func saveLoginCredentials(credentials: LoginCredentials) {
        UserDefaults.standard.set(credentials.serverUrl, forKey: UserDefaultsKey.ServerUrl.rawValue)
        UserDefaults.standard.set(credentials.username, forKey: UserDefaultsKey.Username.rawValue)
        UserDefaults.standard.set(credentials.password, forKey: UserDefaultsKey.Password.rawValue)
        UserDefaults.standard.set(credentials.backendApi.rawValue, forKey: UserDefaultsKey.BackendApi.rawValue)
    }
    
    func deleteLoginCredentials() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.ServerUrl.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Username.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Password.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.BackendApi.rawValue)
    }

    func getLoginCredentials() -> LoginCredentials? {
        if  let serverUrl = UserDefaults.standard.object(forKey: UserDefaultsKey.ServerUrl.rawValue) as? String,
            let username = UserDefaults.standard.object(forKey: UserDefaultsKey.Username.rawValue) as? String,
            let passwordHash = UserDefaults.standard.object(forKey: UserDefaultsKey.Password.rawValue) as? String,
            let backendApiRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.BackendApi.rawValue) as? Int,
            let backendApi = BackenApiType(rawValue: backendApiRaw) {
                return LoginCredentials(serverUrl: serverUrl, username: username, password: passwordHash, backendApi: backendApi)
        } 
        return nil
    }
    
    var isSongsSyncInfoReadByUser: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.SongsSyncInfoReadByUser.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.SongsSyncInfoReadByUser.rawValue) }
    }

    func saveLibraryIsSyncedFlag() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.LibraryIsSynced.rawValue)
    }
    
    func deleteLibraryIsSyncedFlag() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.LibraryIsSynced.rawValue)
    }
    
    func saveSettings(settings: Settings) {
        UserDefaults.standard.set(settings.songActionOnTab.rawValue, forKey: UserDefaultsKey.SongActionOnTab.rawValue)
        UserDefaults.standard.set(settings.playerDisplayStyle.rawValue, forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue)
    }
    
    func getSettings() -> Settings {
        let songActionOnTabRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SongActionOnTab.rawValue) as? Int ?? SongActionOnTab.defaultValue.rawValue
        let songActionOnTab = SongActionOnTab(rawValue: songActionOnTabRaw) ?? SongActionOnTab.defaultValue
        
        let playerDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) as? Int ?? PlayerDisplayStyle.defaultValue.rawValue
        let playerDisplayStyle = PlayerDisplayStyle(rawValue: playerDisplayStyleRaw) ?? PlayerDisplayStyle.defaultValue
        
        return Settings(songActionOnTab: songActionOnTab, playerDisplayStyle: playerDisplayStyle)
    }
    
    func isLibrarySynced() -> Bool {
        guard let isLibrarySynced = UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryIsSynced.rawValue) as? Bool else {
            return false
        }
        return isLibrarySynced
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
