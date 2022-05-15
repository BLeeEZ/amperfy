import Foundation
import CoreData

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

enum SectionIndexType: Int {
    case alphabet = 0
    case rating = 1
    
    static let defaultValue: SectionIndexType = .alphabet
    static let noRatingIndexSymbol = "#"
}

class CustomSectionIndexFetchedResultsController<ResultType: NSFetchRequestResult>: NSFetchedResultsController<NSFetchRequestResult> {
 
    var sectionIndexType: SectionIndexType
    
    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?, cacheName name: String?, sectionIndexType: SectionIndexType = .defaultValue) {
        self.sectionIndexType = sectionIndexType
        super.init(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: name)
    }
    
    override func sectionIndexTitle(forSectionName sectionName: String) -> String? {
        switch sectionIndexType {
        case .alphabet:
            return sortByAlphabet(forSectionName: sectionName)
        case .rating:
            return sortByRating(forSectionName: sectionName)
        }
    }
    
    private func sortByAlphabet(forSectionName sectionName: String) -> String? {
        guard sectionName.count > 0 else { return "?" }
        let initial = String(sectionName.prefix(1).folding(options: .diacriticInsensitive, locale: nil).uppercased())
        if let _ = initial.rangeOfCharacter(from: CharacterSet.decimalDigits) {
            return "#"
        } else if let _ = initial.rangeOfCharacter(from: CharacterSet(charactersIn: String.uppercaseAsciiLetters)) {
            return initial
        } else if let _ = initial.rangeOfCharacter(from: CharacterSet.letters) {
            return "&"
        } else {
            return "?"
        }
    }
    
    private func sortByRating(forSectionName sectionName: String) -> String? {
        guard sectionName.count > 0 else { return SectionIndexType.noRatingIndexSymbol }
        let initial = String(sectionName.prefix(1))
        switch initial {
        case "5": return "5"
        case "4": return "4"
        case "3": return "3"
        case "2": return "2"
        case "1": return "1"
        default: return SectionIndexType.noRatingIndexSymbol
        }
    }
    
}

class BasicFetchedResultsController<ResultType>: NSObject where ResultType : NSFetchRequestResult  {
  
    var fetchResultsController: CustomSectionIndexFetchedResultsController<ResultType>
    let managedObjectContext: NSManagedObjectContext
    let defaultPredicate: NSPredicate?
    let library: LibraryStorage
    var delegate: NSFetchedResultsControllerDelegate? {
        set { fetchResultsController.delegate = newValue }
        get { return fetchResultsController.delegate }
    }
    
    init(managedObjectContext context: NSManagedObjectContext, fetchRequest: NSFetchRequest<ResultType>, isGroupedInAlphabeticSections: Bool) {
        managedObjectContext = context
        library = LibraryStorage(context: context)
        defaultPredicate = fetchRequest.predicate?.copy() as? NSPredicate
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? fetchRequest.sortDescriptors![0].key : nil
        fetchResultsController = CustomSectionIndexFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
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
        return fetchResultsController.fetchedObjects as? [ResultType]
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
    
    func section(forSectionIndexTitle title: String, at index: Int) -> Int {
        return fetchResultsController.section(forSectionIndexTitle: title, at: index)
    }
    
}

extension BasicFetchedResultsController where ResultType == GenreMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Genre {
        let genreMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Genre(managedObject: genreMO)
    }
}

extension BasicFetchedResultsController where ResultType == ArtistMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Artist {
        let artistMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Artist(managedObject: artistMO)
    }
}

extension BasicFetchedResultsController where ResultType == AlbumMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Album(managedObject: albumMO)
    }
}

extension BasicFetchedResultsController where ResultType == SongMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Song(managedObject: songMO)
    }
    
    func getContextSongs(onlyCachedSongs: Bool) -> [AbstractPlayable]? {
        guard let basicPredicate = defaultPredicate else { return nil }
        let cachedFetchRequest = fetchResultsController.fetchRequest.copy() as! NSFetchRequest<SongMO>
        cachedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            basicPredicate,
            library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
        ])
        let songsMO = try? managedObjectContext.fetch(cachedFetchRequest)
        let songs = songsMO?.compactMap{ Song(managedObject: $0) }
        return songs
    }
}

extension BasicFetchedResultsController where ResultType == PlaylistMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
        let playlistMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Playlist(library: LibraryStorage(context: self.managedObjectContext), managedObject: playlistMO)
    }
}

extension BasicFetchedResultsController where ResultType == PlaylistItemMO {
    func getWrappedEntity(at indexPath: IndexPath) -> PlaylistItem {
        let itemMO = fetchResultsController.object(at: indexPath) as! ResultType
        return PlaylistItem(library: library, managedObject: itemMO)
    }
    
    func getContextSongs(onlyCachedSongs: Bool) -> [AbstractPlayable]? {
        guard let basicPredicate = defaultPredicate else { return nil }
        let cachedFetchRequest = fetchResultsController.fetchRequest.copy() as! NSFetchRequest<PlaylistItemMO>
        cachedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            basicPredicate,
            library.getFetchPredicate(onlyCachedPlaylistItems: onlyCachedSongs)
        ])
        let playlistItemsMO = try? managedObjectContext.fetch(cachedFetchRequest)
        let playables = playlistItemsMO?.compactMap{ $0.playable }.compactMap{ AbstractPlayable(managedObject: $0) }
        return playables
    }
}

extension BasicFetchedResultsController where ResultType == LogEntryMO {
    func getWrappedEntity(at indexPath: IndexPath) -> LogEntry {
        let itemMO = fetchResultsController.object(at: indexPath) as! ResultType
        return LogEntry(managedObject: itemMO)
    }
}

extension BasicFetchedResultsController where ResultType == MusicFolderMO {
    func getWrappedEntity(at indexPath: IndexPath) -> MusicFolder {
        let musicFolderMO = fetchResultsController.object(at: indexPath) as! ResultType
        return MusicFolder(managedObject: musicFolderMO)
    }
}

extension BasicFetchedResultsController where ResultType == DirectoryMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Directory {
        let directoryMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Directory(managedObject: directoryMO)
    }
}

extension BasicFetchedResultsController where ResultType == PodcastMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Podcast {
        let podcastMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Podcast(managedObject: podcastMO)
    }
}

extension BasicFetchedResultsController where ResultType == PodcastEpisodeMO {
    func getWrappedEntity(at indexPath: IndexPath) -> PodcastEpisode {
        let podcastEpisodeMO = fetchResultsController.object(at: indexPath) as! ResultType
        return PodcastEpisode(managedObject: podcastEpisodeMO)
    }
}

extension BasicFetchedResultsController where ResultType == DownloadMO {
    func getWrappedEntity(at indexPath: IndexPath) -> Download {
        let downloadMO = fetchResultsController.object(at: indexPath) as! ResultType
        return Download(managedObject: downloadMO)
    }
}


class CachedFetchedResultsController<ResultType>: BasicFetchedResultsController<ResultType> where ResultType : NSFetchRequestResult  {
    
    var keepAllResultsUpdated = true
    private let allFetchResulsController: CustomSectionIndexFetchedResultsController<ResultType>
    private let searchFetchResulsController: CustomSectionIndexFetchedResultsController<ResultType>
    private var sortType: ElementSortType
    
    private var delegateInternal: NSFetchedResultsControllerDelegate?
    override var delegate: NSFetchedResultsControllerDelegate? {
        set {
            delegateInternal = newValue
            updateFetchResultsControllerDelegate()
        }
        get { return delegateInternal }
    }
    private var isSearchActiveInternal = false
    var isSearchActive: Bool {
        set {
            isSearchActiveInternal = newValue
            updateFetchResultsControllerDelegate()
        }
        get { return isSearchActiveInternal }
    }
    
    init(managedObjectContext context: NSManagedObjectContext, fetchRequest: NSFetchRequest<ResultType>, sortType: ElementSortType = .defaultValue, isGroupedInAlphabeticSections: Bool) {
        self.sortType = sortType
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? fetchRequest.sortDescriptors![0].key : nil
        allFetchResulsController = CustomSectionIndexFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: Self.typeName)
        allFetchResulsController.sectionIndexType = sortType == .rating ? .rating : .alphabet
        searchFetchResulsController = CustomSectionIndexFetchedResultsController<ResultType>(fetchRequest: fetchRequest.copy() as! NSFetchRequest<ResultType>, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        searchFetchResulsController.sectionIndexType = sortType == .rating ? .rating : .alphabet
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
    
    private func updateFetchResultsControllerDelegate() {
        fetchResultsController.delegate = nil
        if isSearchActiveInternal {
            fetchResultsController = searchFetchResulsController
        } else {
            fetchResultsController = allFetchResulsController
        }
        if isSearchActiveInternal || (!isSearchActiveInternal && keepAllResultsUpdated) {
            fetchResultsController.delegate = delegateInternal
        }
    }
    
    func hideResults() {
        isSearchActive = true
        searchFetchResulsController.fetchRequest.predicate = NSPredicate(format: "id == nil")
        searchFetchResulsController.fetch()
    }
    
}
