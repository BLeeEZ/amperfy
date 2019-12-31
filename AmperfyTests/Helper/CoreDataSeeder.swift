import Foundation
import CoreData
@testable import Amperfy

class CoreDataSeeder {
    let artists = [
        (id: 4, name: "My Dream"),
        (id: 92, name: "She or He"),
        (id: 93, name: "Bang!")
    ]
    let albums = [
        (id: 12, artistId: 4, name: "High Voltage", year: 2018),
        (id: 34, artistId: 92, name: "Du Hast", year: 1987),
        (id: 59, artistId: 93, name: "Dreams", year: 2002)
    ]
    let songs = [
        (id: 3,     artistId: 4, albumId: 12, track: 3, isCached: false, title: "go home",       url: "www.blub.de/ahhh"),
        (id: 5,     artistId: 4, albumId: 12, track: 4, isCached: false, title: "well",          url: "www.blub.de/ahhh2"),
        (id: 10,    artistId: 4, albumId: 12, track: 8, isCached: false, title: "maybe alright", url: "www.blub.de/dd"),
        (id: 19,    artistId: 92, albumId: 34, track: 0, isCached: false, title: "baby", url: "www.blub.de/dddtd"),
        (id: 36,    artistId: 92, albumId: 34, track: 1, isCached: true, title: "son", url: "www.blub.de/dddtdiuz"),
        (id: 38,    artistId: 93, albumId: 59, track: 4, isCached: true, title: "oh no", url: "www.blub.de/dddtd23iuz"),
        (id: 41,    artistId: 93, albumId: 59, track: 5, isCached: true, title: "please", url: "www.blub.de/dddtd233iuz")
    ]
    let playlists = [
        (id: 3,     name: "With One Cached", songIds: [3, 5, 10, 36, 19]),
        (id: 9,     name: "With Three Cached", songIds: [3, 5, 10, 36, 19, 10, 38, 5, 41]),
        (id: 11,    name: "No Cached", songIds: [3, 10, 19])
    ]
    
    func seed(context: NSManagedObjectContext) {
        let storage = LibraryStorage(context: context)
        
        for artistSeed in artists {
            let artist = storage.createArtist()
            artist.id = Int32(artistSeed.id)
            artist.name = artistSeed.name
        }
        
        for albumSeed in albums {
            let album = storage.createAlbum()
            album.id = albumSeed.id
            album.name = albumSeed.name
            album.year = albumSeed.year
            let artist = storage.getArtist(id: Int32(albumSeed.artistId))
            album.artist = artist
        }
        
        for songSeed in songs {
            let song = storage.createSong()
            song.id = songSeed.id
            song.title = songSeed.title
            song.track = songSeed.track
            song.url = songSeed.url
            let artist = storage.getArtist(id: Int32(songSeed.artistId))
            song.artist = artist
            let album = storage.getAlbum(id: songSeed.albumId)
            song.album = album
            if songSeed.isCached {
                song.fileDataContainer = storage.createSongData()
                song.fileDataContainer?.id = Int32(songSeed.id)
                song.fileDataContainer?.data = NSData(base64Encoded: "Test", options: .ignoreUnknownCharacters)
            }
        }
        
        for playlistSeed in playlists {
            let playlist = storage.createPlaylist()
            playlist.id = Int32(playlistSeed.id)
            playlist.name = playlistSeed.name
            for songId in playlistSeed.songIds {
                if let song = storage.getSong(id: songId) {
                    playlist.append(song: song)
                } else {
                    let logMsg = "Song id <" + String(songId) + "> for playlist id <" + String(playlistSeed.id) + "> could not be found"
                    print(logMsg)
                }
            }
        }
        
        storage.saveContext()
    }
}
