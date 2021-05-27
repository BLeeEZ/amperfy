import Foundation
import CoreData

@objc(MusicFolderMO)
public class MusicFolderMO: NSManagedObject {

    static var idSortedFetchRequest: NSFetchRequest<MusicFolderMO> {
        let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(MusicFolderMO.id), ascending: true)
        ]
        return fetchRequest
    }

    static func getSearchPredicate(searchText: String) -> NSPredicate {
        var predicate: NSPredicate = NSPredicate.alwaysTrue
        if searchText.count > 0 {
            predicate = NSPredicate(format: "%K contains[cd] %@", #keyPath(MusicFolderMO.name), searchText)
        }
        return predicate
    }
    
}
