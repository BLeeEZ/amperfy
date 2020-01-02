import Foundation
import CoreData
import os.log

class LibraryStorage {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "LibraryStorage")
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    static let entitiesToDelete = [Artist.typeName, Album.typeName, Song.typeName, SongFile.typeName, Artwork.typeName, SyncWave.typeName, Playlist.typeName, PlaylistItem.typeName, PlayerData.entityName]
    
    func createArtist() -> Artist {
        let artistMO = ArtistMO(context: context)
        artistMO.artwork = createArtwork().managedObject
        return Artist(managedObject: artistMO)
    }
    
    func createAlbum() -> Album {
        let albumMO = AlbumMO(context: context)
        albumMO.artwork = createArtwork().managedObject
        return Album(managedObject: albumMO)
    }
    
    func createSong() -> Song {
        let songMO = SongMO(context: context)
        songMO.artwork = createArtwork().managedObject
        return Song(managedObject: songMO)
    }
    
    func createSongFile() -> SongFile {
        let songFileMO = SongFileMO(context: context)
        return SongFile(managedObject: songFileMO)
    }
    
    func deleteSongFile(songFile: SongFile) {
        context.delete(songFile.managedObject)
    }

    func deleteCache(ofSong song: Song) {
        if let songFile = song.file {
            deleteSongFile(songFile: songFile)
            song.file = nil
        }
    }

    func deleteCache(ofPlaylist playlist: Playlist) {
        for song in playlist.songs {
            if let songFile = song.file {
                deleteSongFile(songFile: songFile)
                song.file = nil
            }
        }
    }
    
    func deleteCache(ofArtist artist: Artist) {
        for song in artist.songs {
            if let songFile = song.file {
                deleteSongFile(songFile: songFile)
                song.file = nil
            }
        }
    }
    
    func deleteCache(ofAlbum album: Album) {
        for song in album.songs {
            if let songFile = song.file {
                deleteSongFile(songFile: songFile)
                song.file = nil
            }
        }
    }

    func deleteCompleteSongCache() {
        clearStorage(ofType: SongFile.typeName)
    }
    
    func createArtwork() -> Artwork {
        return Artwork(managedObject: ArtworkMO(context: context))
    }
    
    func deleteArtwork(artwork: Artwork) {
        context.delete(artwork.managedObject)
    }
 
    func createPlaylist() -> Playlist {
        return Playlist(storage: self, managedObject: PlaylistMO(context: context))
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist.managedObject)
    }
    
    func createPlaylistItem() -> PlaylistItem {
        let itemMO = PlaylistItemMO(context: context)
        return PlaylistItem(storage: self, managedObject: itemMO)
    }
    
    func deletePlaylistItem(item: PlaylistItem) {
        context.delete(item.managedObject)
    }

    func createSyncWave() -> SyncWave {
        let syncWaveCount = Int16(getSyncWaves().count)
        let syncWaveMO = SyncWaveMO(context: context)
        syncWaveMO.id = syncWaveCount
        return SyncWave(managedObject: syncWaveMO)
    }
    
    func getArtists() -> Array<Artist> {
        var artists = Array<Artist>()
        var foundArtists = Array<ArtistMO>()
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        do {
            foundArtists = try context.fetch(fetchRequest)
            for artistMO in foundArtists {
                artists.append(Artist(managedObject: artistMO))
            }
        }
        catch {}
        
        return artists
    }
    
    func getAlbums() -> Array<Album> {
        var albums = Array<Album>()
        var foundAlbums = Array<AlbumMO>()
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        do {
            foundAlbums = try context.fetch(fetchRequest)
            for albumMO in foundAlbums {
                albums.append(Album(managedObject: albumMO))
            }
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
        var playerMO: PlayerMO
        let fetchRequest: NSFetchRequest<PlayerMO> = PlayerMO.fetchRequest()
        do {
            let fetchResults: Array<PlayerMO> = try context.fetch(fetchRequest)
            if fetchResults.count == 1 {
                playerMO = fetchResults[0]
            } else if (fetchResults.count == 0) {
                playerMO = PlayerMO(context: context)
                saveContext()
            } else {
                clearStorage(ofType: PlayerData.entityName)
                playerMO = PlayerMO(context: context)
                saveContext()
            }
            
            if playerMO.normalPlaylist == nil {
                playerMO.normalPlaylist = PlaylistMO(context: context)
                saveContext()
            }
            if playerMO.shuffledPlaylist == nil {
                playerMO.shuffledPlaylist = PlaylistMO(context: context)
                saveContext()
            }
            
            let normalPlaylist = Playlist(storage: self, managedObject: playerMO.normalPlaylist!)
            let shuffledPlaylist = Playlist(storage: self, managedObject: playerMO.shuffledPlaylist!)
            
            if shuffledPlaylist.items.count != normalPlaylist.items.count {
                shuffledPlaylist.removeAllSongs()
                shuffledPlaylist.append(songs: normalPlaylist.songs)
                shuffledPlaylist.shuffle()
            }
            
            playerData = PlayerData(storage: self, managedObject: playerMO, normalPlaylist: normalPlaylist, shuffledPlaylist: shuffledPlaylist)
            
        } catch {
            fatalError("Not able to get/create" + PlayerData.entityName)
        }
        
        return playerData
    }
    
    func getArtist(id: Int) -> Artist? {
        var foundArtist: Artist? = nil
        let fr: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let artists = result, artists.count > 0, let artist = artists[0] as? ArtistMO {
                foundArtist = Artist(managedObject: artist)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundArtist
    }
    
    func getAlbum(id: Int) -> Album? {
        var foundAlbum: Album? = nil
        let fr: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let albums = result, albums.count > 0, let album = albums[0] as? AlbumMO  {
                foundAlbum = Album(managedObject: album)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundAlbum
    }
    
    func getSong(id: Int) -> Song? {
        var foundSong: Song? = nil
        let fr: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == %@", NSNumber(integerLiteral: id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let songs = result, songs.count > 0, let song = songs[0] as? SongMO  {
                foundSong = Song(managedObject: song)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundSong
    }
    // TODO: id Int
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
        
        let fr: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        fr.predicate = NSPredicate(format: "status == %@", NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue)))
        fr.fetchLimit = fetchCount
        do {
            let result = try context.fetch(fr) as NSArray?
            if let results = result, let artworksMO = results as? [ArtworkMO] {
                for artworkMO in artworksMO {
                    foundArtworks.append(Artwork(managedObject: artworkMO))
                }
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundArtworks
    }

    func getSyncWaves() -> Array<SyncWave> {
        var foundSyncWaves = Array<SyncWave>()
        let fetchRequest: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        do {
            let foundSyncWavesMO = try context.fetch(fetchRequest)
            for syncWave in foundSyncWavesMO {
                foundSyncWaves.append(SyncWave(managedObject: syncWave))
            }
        }
        catch {}
        
        return foundSyncWaves
    }

    func getLatestSyncWave() -> SyncWave? {
        var latestSyncWave: SyncWave? = nil
        let fr: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        fr.predicate = NSPredicate(format: "id == max(id)")
        fr.fetchLimit = 1
        do {
            let result = try self.context.fetch(fr).first
            if let latestSyncWaveMO = result {
                latestSyncWave = SyncWave(managedObject: latestSyncWaveMO)
            }
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
