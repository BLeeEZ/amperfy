import Foundation

class Library {

    private let storage : LibraryStorage

    init(storage : LibraryStorage) {
        self.storage = storage
    }

    func getArtists() -> Array<Artist> {
        return storage.getArtists()
    }

    func getAlbums() -> Array<Album> {
        return storage.getAlbums()
    }
    
    func getSongs() -> Array<Song> {
        return storage.getSongs()
    }
    
    func getPlaylists() -> Array<Playlist> {
        return storage.getPlaylists()
    }
    
    func getPlayerData() -> PlayerData {
        return storage.getPlayerData()
    }
}
