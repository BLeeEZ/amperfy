import Foundation
import CoreData
@testable import Amperfy

class CoreDataHelper {
    
    let seeder: CoreDataSeeder
    lazy var persistentContainer = {
        return NSPersistentContainer(name: "Amperfy", managedObjectModel: PersistentStorage.managedObjectModel)
    }()

    init() {
        seeder = CoreDataSeeder()
    }
    
    func createInMemoryManagedObjectContext() -> NSManagedObjectContext {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false // Make it simpler in test env
        
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores { (description, error) in
            // Check if the data store is in memory
            precondition( description.type == NSInMemoryStoreType )
                                        
            // Check if creating container wrong
            if let error = error {
                fatalError("Create an in-mem coordinator failed \(error)")
            }
        }
        return persistentContainer.viewContext
    }
    
    func clearContext(context: NSManagedObjectContext) {
        for entityName in LibraryStorage.entitiesToDelete {
            let fetchRequest:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let objs = try! context.fetch(fetchRequest)
            for case let obj as NSManagedObject in objs {
                context.delete(obj)
            }
            try! context.save()
        }
    }
    
    func createSeededStorage() -> LibraryStorage {
        let context = createInMemoryManagedObjectContext()
        clearContext(context: context)
        let storage = LibraryStorage(context: context)
        seeder.seed(context: context)
        return storage
    }

}
