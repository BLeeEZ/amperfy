import Foundation
import CoreData

protocol Identifyable {
    var identifier: String { get }
    associatedtype ManagedObjectType where ManagedObjectType : CoreDataIdentifyable
    var managedObject: ManagedObjectType { get }
}

protocol CoreDataIdentifyable where Self: NSFetchRequestResult {
    static var identifierKey: KeyPath<Self, String?> { get }
    static var identifierKeyString: String { get }
    static var identifierSortedFetchRequest: NSFetchRequest<Self> { get }
    static func getIdentifierBasedSearchPredicate(searchText: String) -> NSPredicate
    static func fetchRequest() -> NSFetchRequest<Self>
}

extension CoreDataIdentifyable {
    static var identifierKeyString: String {
        return NSExpression(forKeyPath: Self.identifierKey).keyPath
    }
    
    static func getIdentifierBasedSearchPredicate(searchText: String) -> NSPredicate {
        var predicate: NSPredicate = NSPredicate.alwaysTrue
        if searchText.count > 0 {
            predicate = NSPredicate(format: "%K contains[cd] %@", Self.identifierKeyString, searchText)
        }
        return predicate
    }
    
    static var identifierSortedFetchRequest: NSFetchRequest<Self> {
        let fetchRequest: NSFetchRequest<Self> = Self.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: Self.identifierKeyString, ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare)),
            NSSortDescriptor(key: "id", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }
}

extension Array where Element: Identifyable {
    
    func filterBy(searchText: String) -> [Element] {
        let filteredArray = self.filter { element in
            return element.identifier.isFoundBy(searchText: searchText)
        }
        return filteredArray
    }
    
    func sortAlphabeticallyAscending() -> [Element] {
        return self.sorted{
            return $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == ComparisonResult.orderedAscending
        }
    }
    
    func sortAlphabeticallyDescending() -> [Element] {
        return self.sorted{
            return $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == ComparisonResult.orderedDescending
        }
    }
    
}
