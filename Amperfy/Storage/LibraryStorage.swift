import Foundation
import CoreData
import os.log

class LibraryStorage {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "LibraryStorage")
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    static let entitiesToDelete = [Artist.typeName, Album.typeName, Song.typeName, SongDataMO.typeName, Artwork.typeName, SyncWaveMO.typeName, Playlist.typeName, PlaylistElement.typeName, PlayerManaged.typeName]
    
    func createArtist() -> Artist {
        let artist = Artist(context: context)
        artist.artwork = createArtwork()
        return artist
    }
    
    func createAlbum() -> Album {
        let album = Album(context: context)
        album.artwork = createArtwork()
        return album
    }
    
    func createSong() -> Song {
        let songMO = SongMO(context: context)
        songMO.artwork = createArtwork()
        return Song(managedObject: songMO)
    }
    
    func createSongData() -> SongDataMO {
        let songData = SongDataMO(context: context)
        return songData
    }
    
    func deleteSongData(songData: SongDataMO) {
        context.delete(songData)
    }

    func deleteCache(ofSong song: Song) {
        if let songData = song.fileDataContainer {
            deleteSongData(songData: songData)
            song.fileDataContainer = nil
        }
    }

    func deleteCache(ofPlaylist playlist: Playlist) {
        for song in playlist.songs {
            if let songData = song.fileDataContainer {
                deleteSongData(songData: songData)
                song.fileDataContainer = nil
            }
        }
    }
    
    func deleteCache(ofArtist artist: Artist) {
        for song in artist.songs {
            if let songData = song.fileDataContainer {
                deleteSongData(songData: songData)
                song.fileDataContainer = nil
            }
        }
    }
    
    func deleteCache(ofAlbum album: Album) {
        for song in album.songs {
            if let songData = song.fileDataContainer {
                deleteSongData(songData: songData)
                song.fileDataContainer = nil
            }
        }
    }

    func deleteCompleteSongCache() {
        clearStorage(ofType: SongDataMO.typeName)
    }
    
    func createArtwork() -> Artwork {
        return Artwork(context: context)
    }
    
    func deleteArtwork(artwork: Artwork) {
        context.delete(artwork)
    }
 
    func createPlaylist() -> Playlist {
        return Playlist(storage: self, managedObject: PlaylistMO(context: context))
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist.managedObject)
    }
    
    func createPlaylistElement() -> PlaylistElement {
        let elementMO = PlaylistElementMO(context: context)
        return PlaylistElement(storage: self, managedObject: elementMO)
    }
    
    func deletePlaylistElement(element: PlaylistElement) {
        context.delete(element.managedObject)
    }

    func createSyncWave() -> SyncWaveMO {
        let syncWave = SyncWaveMO(context: context)
        syncWave.id = Int16(getSyncWaves().count)
        return syncWave
    }
    
    func getArtists() -> Array<Artist> {
        var artists = Array<Artist>()
        let fetchRequest: NSFetchRequest<Artist> = Artist.fetchRequest()
        do {
            artists = try context.fetch(fetchRequest)
        }
        catch {}
        
        return artists
    }
    
    func getAlbums() -> Array<Album> {
        var albums = Array<Album>()
        let fetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
        do {
            albums = try context.fetch(fetchRequest)
        }
        catch {}
        
        return albums
    }
    
    func getSongs() -> Array<Song> {
        var songs = Array<Song>()
        var foundSongs = Array<SongMO>()
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        do {
            foundSongs = try context.fetch(fetchRequest)
            for songMO in foundSongs {
                songs.append(Song(managedObject: songMO))
            }
        }
        catch {}
        
        return songs
    }
    
    func getPlaylists() -> Array<Playlist> {
        var foundPlaylists = Array<Playlist>()
        let fr: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fr.predicate = NSPredicate(format: "playersNormalPlaylist == nil && playersShuffledPlaylist == nil")
        do {
            let result = try context.fetch(fr) as NSArray?
            if let playlists = result as? Array<PlaylistMO> {
                for playlist in playlists {
                    let wrappedPlaylist = Playlist(storage: self, managedObject: playlist)
                    foundPlaylists.append(wrappedPlaylist)
                }
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundPlaylists
    }
    
    func getPlayerData() -> PlayerData {
        var playerData: PlayerData
        var playerManaged: PlayerManaged
        let fetchRequest: NSFetchRequest<PlayerManaged> = PlayerManaged.fetchRequest()
        do {
            let fetchResults: Array<PlayerManaged> = try context.fetch(fetchRequest)
            if fetchResults.count == 1 {
                playerManaged = fetchResults[0]
            } else {
                clearStorage(ofType: PlayerManaged.typeName)
                playerManaged = PlayerManaged(context: context)
                saveContext()
            }
            
            if playerManaged.normalPlaylist == nil {
                playerManaged.normalPlaylist = PlaylistMO(context: context)
                saveContext()
            }
            if playerManaged.shuffledPlaylist == nil {
                playerManaged.shuffledPlaylist = PlaylistMO(context: context)
                saveContext()
            }
            
            let normalPlaylist = Playlist(storage: self, managedObject: playerManaged.normalPlaylist!)
            let shuffledPlaylist = Playlist(storage: self, managedObject: playerManaged.shuffledPlaylist!)
            
            if shuffledPlaylist.entries.count != normalPlaylist.entries.count {
                shuffledPlaylist.removeAllSongs()
                shuffledPlaylist.append(songs: normalPlaylist.songs)
                shuffledPlaylist.shuffle()
            }
            
            playerData = PlayerData(storage: self, managedPlayer: playerManaged, normalPlaylist: normalPlaylist, shuffledPlaylist: shuffledPlaylist)
            
        } catch {
            fatalError("Not able to get/create" + PlayerManaged.typeName)
        }
        
        return playerData
    }
    
    func getArtist(id: Int32) -> Artist? {
        var foundArtist: Artist? = nil
        let fr: NSFetchRequest<Artist> = Artist.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: Int(id)))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let artists = result, artists.count > 0, let artist = artists[0] as? Artist {
                foundArtist = artist
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundArtist
    }
    
    func getAlbum(id: Int32) -> Album? {
        var foundAlbum: Album? = nil
        let fr: NSFetchRequest<Album> = Album.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: Int(id)))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let albums = result, albums.count > 0, let album = albums[0] as? Album  {
                foundAlbum = album
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundAlbum
    }
    
    func getSong(id: Int) -> Song? {
        var foundSongMO: SongMO? = nil
        let fr: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let songs = result, songs.count > 0, let song = songs[0] as? SongMO  {
                foundSongMO = song
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        
        guard let foundSong = foundSongMO else {
            return nil
        }
        return Song(managedObject: foundSong)
    }
    
    func getPlaylist(id: Int32) -> Playlist? {
        var foundPlaylist: Playlist? = nil
        let fr: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: Int(id)))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let playlists = result, playlists.count > 0, let playlist = playlists[0] as? PlaylistMO  {
                foundPlaylist = Playlist(storage: self, managedObject: playlist)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundPlaylist
    }
    
    func getPlaylist(viaPlaylistFromOtherContext: Playlist) -> Playlist? {
        guard let foundManagedPlaylist = context.object(with: viaPlaylistFromOtherContext.managedObject.objectID) as? PlaylistMO else { return nil }
        return Playlist(storage: self, managedObject: foundManagedPlaylist)
    }
    
    func getArtworksThatAreNotChecked(fetchCount: Int = 10) -> [Artwork] {
        var foundArtworks = [Artwork]()
        
        let fr: NSFetchRequest<Artwork> = Artwork.fetchRequest()
        fr.predicate = NSPredicate(format: "statusMO == %@", NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue)))
        fr.fetchLimit = fetchCount
        do {
            let result = try context.fetch(fr) as NSArray?
            if let results = result, let artworks = results as? [Artwork] {
                foundArtworks = artworks
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundArtworks
    }

    func getSyncWaves() -> Array<SyncWaveMO> {
        var syncWaves = Array<SyncWaveMO>()
        let fetchRequest: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        do {
            syncWaves = try context.fetch(fetchRequest)
        }
        catch {}
        
        return syncWaves
    }

    func getLatestSyncWave() -> SyncWaveMO? {
        var latestSyncWave: SyncWaveMO? = nil
        let fr: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == max(id)")
        fr.fetchLimit = 1
        do {
            latestSyncWave = try self.context.fetch(fr).first
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return latestSyncWave
    }
    
    func cleanStorage() {
        for entityToDelete in LibraryStorage.entitiesToDelete {
            clearStorage(ofType: entityToDelete)
        }
        saveContext()
    }
    
    private func clearStorage(ofType entityToDelete: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityToDelete)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch let error as NSError {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func saveContext () {
        if context.hasChanges {
            do {
                context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
}
