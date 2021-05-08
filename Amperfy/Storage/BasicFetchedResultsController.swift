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

extension GenreMO {
    @objc public var section: String {
        self.willAccessValue(forKey: "section")
        let section = FetchedResultsControllerSectioner.getSectionIdentifier(element: self.name)
        self.didAccessValue(forKey: "section")
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
  
    var fetchResultsController: NSFetchedResultsController<ResultType>
    let managedObjectContext: NSManagedObjectContext
    let defaultPredicate: NSPredicate?
    let library: LibraryStorage
    
    var delegateInternal: NSFetchedResultsControllerDelegate?
    var delegate: NSFetchedResultsControllerDelegate? {
        set {
            delegateInternal = newValue
            fetchResultsController.delegate = newValue
        }
        get { return delegateInternal }
    }
    
    init(managedObjectContext context: NSManagedObjectContext, fetchRequest: NSFetchRequest<ResultType>, isGroupedInAlphabeticSections: Bool) {
        managedObjectContext = context
        library = LibraryStorage(context: context)
        defaultPredicate = fetchRequest.predicate?.copy() as? NSPredicate
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        fetchResultsController = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    func search(predicate: NSPredicate?) {
        fetchResultsController.fetchRequest.predicate = predicate
        fetchResultsController.fetch()
    }
    
    func fetch() {
        fetchResultsController.fetch()
    }
    
    func clearResults() {
        fetchResultsController.clearResults()
    }
    
    func showAllResults() {
        fetchResultsController.fetchRequest.predicate = defaultPredicate
        fetch()
    }
    
    var fetchedObjects: [ResultType]? {
        return fetchResultsController.fetchedObjects
    }
    
    var sections: [NSFetchedResultsSectionInfo]? {
        return fetchResultsController.sections
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

extension BasicFetchedResultsController where ResultType == GenreMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Genre {
        let genreMO = fetchResultsController.object(at: indexPath)
        return Genre(managedObject: genreMO)
    }
}

extension BasicFetchedResultsController where ResultType == ArtistMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Artist {
        let artistMO = fetchResultsController.object(at: indexPath)
        return Artist(managedObject: artistMO)
    }
}

extension BasicFetchedResultsController where ResultType == AlbumMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = fetchResultsController.object(at: indexPath)
        return Album(managedObject: albumMO)
    }
}

extension BasicFetchedResultsController where ResultType == SongMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        return Song(managedObject: songMO)
    }
}

extension BasicFetchedResultsController where ResultType == PlaylistMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
        let playlistMO = fetchResultsController.object(at: indexPath)
        return Playlist(storage: LibraryStorage(context: self.managedObjectContext), managedObject: playlistMO)
    }
}

extension BasicFetchedResultsController where ResultType == PlaylistItemMO {
    func getWrappedEntity(at indexPath: IndexPath) -> PlaylistItem {
        let itemMO = fetchResultsController.object(at: indexPath)
        return PlaylistItem(storage: library, managedObject: itemMO)
    }
}

class CachedFetchedResultsController<ResultType>: BasicFetchedResultsController<ResultType> where ResultType : NSFetchRequestResult  {
    
    private let allFetchResulsController: NSFetchedResultsController<ResultType>
    private let searchFetchResulsController: NSFetchedResultsController<ResultType>
    
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
    
    override init(managedObjectContext context: NSManagedObjectContext, fetchRequest: NSFetchRequest<ResultType>, isGroupedInAlphabeticSections: Bool) {
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        allFetchResulsController = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: Self.typeName)
        searchFetchResulsController = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
        fetchResultsController = allFetchResulsController
    }
    
    override func search(predicate: NSPredicate?) {
        isSearchActive = true
        searchFetchResulsController.fetchRequest.predicate = predicate
        searchFetchResulsController.fetch()
    }
    
    static func deleteCache() {
        NSFetchedResultsController<ResultType>.deleteCache(withName: Self.typeName)
    }
    
    override func fetch() {
        isSearchActive = false
        allFetchResulsController.fetch()
    }
    
    override func showAllResults() {
        fetch()
    }
    
    override func clearResults() {
        isSearchActive = true
        searchFetchResulsController.clearResults()
    }
    
}
