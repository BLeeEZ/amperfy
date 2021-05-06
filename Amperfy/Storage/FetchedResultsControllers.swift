import Foundation
import CoreData

class GenreFetchedResultsController: CachedFetchedResultsController<GenreMO> {
    
    init(managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        let library = LibraryStorage(context: context)
        let fetchRequest = library.genresFetchRequest
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Genre {
        let genreMO = fetchResultsController.object(at: indexPath)
        return Genre(managedObject: genreMO)
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getGenresFetchPredicate(searchText: searchText))
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
        let fetchRequest = library.getArtistsFetchRequest(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Artist {
        let artistMO = fetchResultsController.object(at: indexPath)
        let artist = Artist(managedObject: artistMO)
        return artist
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getArtistsFetchPredicate(forGenre: genre, searchText: searchText))
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
        let fetchRequest = library.getAlbumsFetchRequest(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = fetchResultsController.object(at: indexPath)
        let album = Album(managedObject: albumMO)
        return album
    }
    
    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getAlbumsFetchPredicate(forGenre: genre, searchText: searchText))
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
        let fetchRequest = library.getSongsFetchRequest(forGenre: genre)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            search(predicate: library.getSongsFetchPredicate(forGenre: genre, searchText: searchText, onlyCachedSongs: onlyCachedSongs))
        } else {
            showAllResults()
        }
    }

}

class ArtistFetchedResultsController: CachedFetchedResultsController<ArtistMO> {
    
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

class ArtistAlbumsItemsFetchedResultsController: BasicFetchedResultsController<AlbumMO> {

    let artist: Artist
    
    init(for artist: Artist, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.artist = artist
        let library = LibraryStorage(context: context)
        let fetchRequest = library.getAlbumsFetchRequest(forArtist: artist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    func getWrappedEntity(at indexPath: IndexPath) -> Album {
        let albumMO = fetchResultsController.object(at: indexPath)
        let album = Album(managedObject: albumMO)
        return album
    }

    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getAlbumsFetchPredicate(forArtist: artist, searchText: searchText))
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
        let fetchRequest = library.getSongsFetchRequest(forArtist: artist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }

    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            search(predicate: library.getSongsFetchPredicate(forArtist: artist, searchText: searchText, onlyCachedSongs: onlyCachedSongs))
        } else {
            showAllResults()
        }
    }

}

class AlbumFetchedResultsController: CachedFetchedResultsController<AlbumMO> {
    
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

class SongFetchedResultsController: CachedFetchedResultsController<SongMO> {
    
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

class LatestSongsFetchedResultsController: CachedFetchedResultsController<SongMO> {
    
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

class AlbumSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let album: Album
    
    init(forAlbum album: Album, managedObjectContext context: NSManagedObjectContext, isGroupedInAlphabeticSections: Bool) {
        self.album = album
        let library = LibraryStorage(context: context)
        let fetchRequest = library.getSongsFetchRequest(forAlbum: album)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    func getWrappedEntity(at indexPath: IndexPath) -> Song {
        let songMO = fetchResultsController.object(at: indexPath)
        let song = Song(managedObject: songMO)
        return song
    }
    
    func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            search(predicate: library.getSongsFetchPredicate(forAlbum: album, searchText: searchText, onlyCachedSongs: onlyCachedSongs))
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
        let fetchRequest = library.getPlaylistItemsFetchRequest(for: playlist)
        super.init(managedObjectContext: context, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    func getWrappedEntity(at indexPath: IndexPath) -> PlaylistItem {
        let itemMO = fetchResultsController.object(at: indexPath)
        let item = PlaylistItem(storage: library, managedObject: itemMO)
        return item
    }

    func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: library.getPlaylistItemsFetchPredicate(for: playlist, searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

class PlaylistFetchedResultsController: CachedFetchedResultsController<PlaylistMO> {

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

class PlaylistSelectorFetchedResultsController: CachedFetchedResultsController<PlaylistMO> {

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
