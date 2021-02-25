import Foundation

class Library {

    private let storage : LibraryStorage

    init(storage : LibraryStorage) {
        self.storage = storage
    }

    func getArtists() -> Array<Artist> {
        return storage.getArtists()
    }
    
    func getArtistsAsync(completion: @escaping (_ artists: Array<Artist>) -> Void) {
        return storage.getArtistsAsync(completion: completion)
    }

    func getAlbums() -> Array<Album> {
        return storage.getAlbums()
    }

    func getAlbumsAsync(completion: @escaping (_ albums: Array<Album>) -> Void) {
        return storage.getAlbumsAsync(completion: completion)
    }

    func getSongs() -> Array<Song> {
        return storage.getSongs()
    }

    func getSongsAsync(completion: @escaping (_ albums: Array<Song>) -> Void) {
        return storage.getSongsAsync(completion: completion)
    }

    func getPlaylists() -> Array<Playlist> {
        return storage.getPlaylists()
    }

    func getPlaylistsAsync(completion: @escaping (_ albums: Array<Playlist>) -> Void) {
        return storage.getPlaylistsAsync(completion: completion)
    }

    func getPlayerData() -> PlayerData {
        return storage.getPlayerData()
    }
}
