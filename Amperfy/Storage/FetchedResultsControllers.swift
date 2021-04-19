import Foundation
import CoreData

class ArtistFetchedResultsController: BasicFetchedResultsController<ArtistMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.artistsFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Artist {
        let artistMO = fetchResultsController.object(at: indexPath)
        let artist = Artist(managedObject: artistMO)
        return artist
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getArtistsFetchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class AlbumFetchedResultsController: BasicFetchedResultsController<AlbumMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.albumsFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = fetchResultsController.object(at: indexPath)
        let album = Album(managedObject: albumMO)
        return album
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getAlbumsFetchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class SongFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.songsFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            search(predicate: library.getSongsFetchPredicate(searchText: searchText, onlyCachedSongs: onlyCachedSongs))
        } else {
            showAllResults()
        }
    }

}

class LatestSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    private let latestSyncWave: SyncWave?
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        latestSyncWave = library.getLatestSyncWaveWithChanges()
        let fetchRequest = library.songsFetchRequest
        fetchRequest.predicate = library.getSongsFetchPredicate(ofSyncWave: latestSyncWave, searchText: "", onlyCachedSongs: false)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            search(predicate: library.getSongsFetchPredicate(ofSyncWave: latestSyncWave, searchText: searchText, onlyCachedSongs: onlyCachedSongs))
        } else {
            showAllResults()
        }
    }

}

class PlaylistFetchedResultsController: BasicFetchedResultsController<PlaylistMO> {

    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.playlistsFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
        let playlistMO = fetchResultsController.object(at: indexPath)
        let playlist = Playlist(storage: LibraryStorage(context: self.managedObjectContext), managedObject: playlistMO)
        return playlist
    }
    
    func search(searchText: String, playlistSearchCategory: PlaylistSearchCategory) {
        if searchText.count > 0 || playlistSearchCategory != .defaultValue {
            search(predicate: library.getPlaylistsFetchPredicate(searchText: searchText, playlistSearchCategory: playlistSearchCategory))
        } else {
            showAllResults()
        }
    }

}

class PlaylistSelectorFetchedResultsController: BasicFetchedResultsController<PlaylistMO> {

    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.playlistsFetchRequest
        fetchRequest.predicate = library.getPlaylistsFetchPredicate(searchText: "", playlistSearchCategory: .userOnly)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Playlist {
        let playlistMO = fetchResultsController.object(at: indexPath)
        let playlist = Playlist(storage: LibraryStorage(context: self.managedObjectContext), managedObject: playlistMO)
        return playlist
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getPlaylistsFetchPredicate(searchText: searchText, playlistSearchCategory: .userOnly))
        } else {
            showAllResults()
        }
    }

}
