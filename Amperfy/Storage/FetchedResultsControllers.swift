import Foundation
import CoreData

class GenreFetchedResultsController: CachedFetchedResultsController<GenreMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = GenreMO.identifierSortedFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
        
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: GenreMO.getIdentifierBasedSearchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class GenreArtistsFetchedResultsController: BasicFetchedResultsController<ArtistMO> {
    
    let genre: Genre
    
    init(for genre: Genre, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let library = LibraryStorage(context: context)
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forGenre: genre),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class GenreAlbumsFetchedResultsController: BasicFetchedResultsController<AlbumMO> {
    
    let genre: Genre
    
    init(for genre: Genre, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let library = LibraryStorage(context: context)
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forGenre: genre),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class GenreSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let genre: Genre
    
    init(for genre: Genre, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let library = LibraryStorage(context: context)
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forGenre: genre),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class ArtistFetchedResultsController: CachedFetchedResultsController<ArtistMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class ArtistAlbumsItemsFetchedResultsController: BasicFetchedResultsController<AlbumMO> {

    let artist: Artist
    
    init(for artist: Artist, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.artist = artist
        let library = LibraryStorage(context: context)
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forArtist: artist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forArtist: artist),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class ArtistSongsItemsFetchedResultsController: BasicFetchedResultsController<SongMO> {

    let artist: Artist
    
    init(for artist: Artist, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.artist = artist
        let library = LibraryStorage(context: context)
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forArtist: artist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forArtist: artist),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class AlbumFetchedResultsController: CachedFetchedResultsController<AlbumMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: AlbumMO.getIdentifierBasedSearchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class SongFetchedResultsController: CachedFetchedResultsController<SongMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class AlbumSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let album: Album
    
    init(forAlbum album: Album, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.album = album
        let library = LibraryStorage(context: context)
        let fetchRequest = SongMO.trackNumberSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forAlbum: album)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                library.getFetchPredicate(forAlbum: album),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class PlaylistItemsFetchedResultsController: BasicFetchedResultsController<PlaylistItemMO> {

    let playlist: Playlist
    
    init(forPlaylist playlist: Playlist, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.playlist = playlist
        let library = LibraryStorage(context: context)
        let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
        fetchRequest.predicate = library.getFetchPredicate(forPlaylist: playlist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

}

class PlaylistFetchedResultsController: CachedFetchedResultsController<PlaylistMO> {

    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String, playlistSearchCategory: PlaylistSearchCategory) {
        if searchText.count > 0 || playlistSearchCategory != .defaultValue {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                PlaylistMO.excludeSystemPlaylistsFetchPredicate,
                PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(forPlaylistSearchCategory: playlistSearchCategory)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class PlaylistSelectorFetchedResultsController: CachedFetchedResultsController<PlaylistMO> {

    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            PlaylistMO.excludeSystemPlaylistsFetchPredicate,
            library.getFetchPredicate(forPlaylistSearchCategory: .userOnly)
        ])
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                PlaylistMO.excludeSystemPlaylistsFetchPredicate,
                PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                library.getFetchPredicate(forPlaylistSearchCategory: .userOnly)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

class ErrorLogFetchedResultsController: BasicFetchedResultsController<LogEntryMO> {

    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = LogEntryMO.creationDateSortedFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

}
