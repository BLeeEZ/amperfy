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

class ArtistFetchedResultsController: NSFetchedResultsController<ArtistMO> {
    
    let library: LibraryStorage
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        library = LibraryStorage(context: context)
        let fetchRequest = library.artistsFetchRequest
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        super.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Artist {
        let artistMO = self.object(at: indexPath)
        let artist = Artist(managedObject: artistMO)
        return artist
    }
    
    func search(searchText: String) {
        fetchRequest.predicate = library.getArtistsFetchPredicate(searchText: searchText)
        fetch()
    }

}

class AlbumFetchedResultsController: NSFetchedResultsController<AlbumMO> {
    
    let library: LibraryStorage
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        library = LibraryStorage(context: context)
        let fetchRequest = library.albumsFetchRequest
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        super.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = self.object(at: indexPath)
        let album = Album(managedObject: albumMO)
        return album
    }
    
    func search(searchText: String) {
        fetchRequest.predicate = library.getAlbumsFetchPredicate(searchText: searchText)
        fetch()
    }

}

class SongFetchedResultsController: NSFetchedResultsController<SongMO> {
    
    let library: LibraryStorage
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        library = LibraryStorage(context: context)
        let fetchRequest = library.songsFetchRequest
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        super.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = self.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        fetchRequest.predicate = library.getSongsFetchPredicate(searchText: searchText, onlyCachedSongs: onlyCachedSongs)
        fetch()
    }

}

class LatestSongsFetchedResultsController: NSFetchedResultsController<SongMO> {
    
    let library: LibraryStorage
    private let latestSyncWave: SyncWave?
    
    init(managedObjectContext context: NSManagedObjectContext) {
        library = LibraryStorage(context: context)
        latestSyncWave = library.getLatestSyncWave()
        let fetchRequest = library.songsFetchRequest
        fetchRequest.predicate = library.getSongsFetchPredicate(ofSyncWave: latestSyncWave, searchText: "", onlyCachedSongs: false)
        super.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: "section", cacheName: nil)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = self.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        fetchRequest.predicate = library.getSongsFetchPredicate(ofSyncWave: latestSyncWave, searchText: searchText, onlyCachedSongs: onlyCachedSongs)
        fetch()
    }

}


class PlaylistFetchedResultsController: NSFetchedResultsController<PlaylistMO> {
    
    let library: LibraryStorage
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        library = LibraryStorage(context: context)
        let fetchRequest = library.playlistsFetchRequest
        let sectionNameKeyPath: String? = isGroupedInAlphabeticSections ? "section" : nil
        super.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
        let playlistMO = self.object(at: indexPath)
        let playlist = Playlist(storage: LibraryStorage(context: self.managedObjectContext), managedObject: playlistMO)
        return playlist
    }
    
    func search(searchText: String, playlistSearchCategory: PlaylistSearchCategory) {
        fetchRequest.predicate = library.getPlaylistsFetchPredicate(searchText: searchText, playlistSearchCategory: playlistSearchCategory)
        fetch()
    }

}
