import Foundation
import CoreData

class FetchedResultsControllerSectioner {
    static func getSectionIdentifier(element: String?) -> String {
        let initial = String(element?.prefix(1).lowercased() ?? "")
        var section = ""
        if initial < "a" {
            section = "#"
        } else if initial > "z" {
            section = "?"
        } else {
            section = initial
        }
        return section
    }
}

extension ArtistMO {
    @objc public var section: String {
        self.willAccessValue(forKey: "section")
        let section = FetchedResultsControllerSectioner.getSectionIdentifier(element: self.name)
        self.didAccessValue(forKey: "section")
        return section
    }
}

extension AlbumMO {
    @objc public var section: String {
        self.willAccessValue(forKey: "section")
        let section = FetchedResultsControllerSectioner.getSectionIdentifier(element: self.name)
        self.didAccessValue(forKey: "section")
        return section
    }
}

extension SongMO {
    @objc public var section: String {
        self.willAccessValue(forKey: "section")
        let section = FetchedResultsControllerSectioner.getSectionIdentifier(element: self.title)
        self.didAccessValue(forKey: "section")
        return section
    }
}

extension PlaylistMO {
    @objc public var section: String {
        self.willAccessValue(forKey: "section")
        let section = FetchedResultsControllerSectioner.getSectionIdentifier(element: self.name)
        self.didAccessValue(forKey: "section")
        return section
    }
}

extension NSFetchedResultsController {
    @objc func fetch() {
        do {
            try self.performFetch()
        } catch let error as NSError {
            print("Unable to perform fetch: \(error.localizedDescription)")
        }
    }
    
    @objc func clearResults() {
        let oldPredicate = fetchRequest.predicate
        fetchRequest.predicate = NSPredicate(format: "id == nil")
        fetch()
        fetchRequest.predicate = oldPredicate
    }
}

class BasicFetchedResultsController<ResultType>: NSObject where ResultType : NSFetchRequestResult  {
    
    let library: LibraryStorage
    let managedObjectContext: NSManagedObjectContext
    
    var fetchResultsController: NSFetchedResultsController<ResultType>
    private let allFetchResulsController: NSFetchedResultsController<ResultType>
    private let searchFetchResulsController: NSFetchedResultsController<ResultType>
    
    private var delegateInternal: NSFetchedResultsControllerDelegate?
    var delegate: NSFetchedResultsControllerDelegate? {
        set {
            delegateInternal = newValue
            fetchResultsController.delegate = newValue
        }
        get { return delegateInternal }
    }
    
    private var isSearchActiveInternal = false
    var isSearchActive: Bool {
        set {
            isSearchActiveInternal = newValue
            fetchResultsController.delegate = nil
            if isSearchActiveInternal {
                fetchResultsController = searchFetchResulsController
            } else {
                fetchResultsController = allFetchResulsController
            }
            fetchResultsController.delegate = delegateInternal
        }
        get { return isSearchActiveInternal }
    }
    
    var fetchedObjects: [ResultType]? {
        return fetchResultsController.fetchedObjects
    }
    
    var sections: [NSFetchedResultsSectionInfo]? {
        return fetchResultsController.sections
    }
    
    init(managedObjectContext context: NSManagedObjectContext, fetchRequest: NSFetchRequest<ResultType>, isGroupedInAlphabeticSections: Bool) {
        managedObjectContext = context
        library = LibraryStorage(context: context)
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        allFetchResulsController = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: Self.typeName)
        searchFetchResulsController = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        fetchResultsController = allFetchResulsController
    }
    
    func search(predicate: NSPredicate?) {
        isSearchActive = true
        searchFetchResulsController.fetchRequest.predicate = predicate
        searchFetchResulsController.fetch()
    }
    
    func showAllResults() {
        fetch()
    }
    
    static func deleteCache() {
        NSFetchedResultsController<ResultType>.deleteCache(withName: Self.typeName)
    }
    
    func fetch() {
        isSearchActive = false
        allFetchResulsController.fetch()
    }
    
    func clearResults() {
        isSearchActive = true
        searchFetchResulsController.clearResults()
    }
    
    var numberOfSections: Int {
        return fetchResultsController.sections?.count ?? 0
    }

    func titleForHeader(inSection section: Int) -> String? {
        return fetchResultsController.sectionIndexTitles[section]
    }

    func numberOfRows(inSection section: Int) -> Int {
        return fetchResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    var sectionIndexTitles: [String]? {
        return fetchResultsController.sectionIndexTitles
    }
    
}
