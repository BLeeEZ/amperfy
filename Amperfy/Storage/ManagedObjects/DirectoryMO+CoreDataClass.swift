import Foundation
import CoreData

@objc(DirectoryMO)
public final class DirectoryMO: AbstractLibraryEntityMO {

    static var nameSortedFetchRequest: NSFetchRequest<DirectoryMO> {
        let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(DirectoryMO.name), ascending: true)
        ]
        return fetchRequest
    }

    static func getSearchPredicate(searchText: String) -> NSPredicate {
        var predicate: NSPredicate = NSPredicate.alwaysTrue
        if searchText.count > 0 {
            predicate = NSPredicate(format: "%K contains[cd] %@", #keyPath(DirectoryMO.name), searchText)
        }
        return predicate
    }

}

extension DirectoryMO: CoreDataIdentifyable {
    
    static var identifierKey: WritableKeyPath<DirectoryMO, String?> {
        return \DirectoryMO.name
    }
    
}
