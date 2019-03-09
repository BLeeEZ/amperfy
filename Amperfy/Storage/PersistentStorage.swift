import Foundation
import CoreData

enum UserDefaultsKey: String {
    case ServerUrl = "serverUrl"
    case Username = "username"
    case PasswordHash = "passwordHash"
    case AmpacheIsSynced = "ampacheIsSynced"
}

class PersistentStorage {

    init() {
    }

    func saveLoginCredentials(credentials: LoginCredentials) {
        UserDefaults.standard.set(credentials.serverUrl, forKey: UserDefaultsKey.ServerUrl.rawValue)
        UserDefaults.standard.set(credentials.username, forKey: UserDefaultsKey.Username.rawValue)
        UserDefaults.standard.set(credentials.passwordHash, forKey: UserDefaultsKey.PasswordHash.rawValue)
    }
    
    func deleteLoginCredentials() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.ServerUrl.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Username.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.PasswordHash.rawValue)
    }

    func getLoginCredentials() -> LoginCredentials? {
        let credentials = LoginCredentials()
        if  let serverUrl = UserDefaults.standard.object(forKey: UserDefaultsKey.ServerUrl.rawValue) as? String,
            let username = UserDefaults.standard.object(forKey: UserDefaultsKey.Username.rawValue) as? String,
            let passwordHash = UserDefaults.standard.object(forKey: UserDefaultsKey.PasswordHash.rawValue) as? String {
                credentials.serverUrl = serverUrl
                credentials.username = username
                credentials.passwordHash = passwordHash
                return credentials
        } 
        return nil
    }
    
    func saveAmpacheIsSynced() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.AmpacheIsSynced.rawValue)
    }
    
    func deleteAmpacheIsSynced() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.AmpacheIsSynced.rawValue)
    }
    
    func isAmpacheSynced() -> Bool {
        guard let isAmpacheSynced = UserDefaults.standard.object(forKey: UserDefaultsKey.AmpacheIsSynced.rawValue) as? Bool else {
            return false
        }
        return isAmpacheSynced
    }

    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Amperfy")
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
