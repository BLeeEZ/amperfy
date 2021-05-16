import Foundation
import CoreData
import os.log

protocol SongFileCachable {
    func getSongFile(forSong song: Song) -> SongFile?
}

enum PlaylistSearchCategory: Int {
    case all = 0
    case userOnly = 1
    case smartOnly = 2

    static let defaultValue: PlaylistSearchCategory = .all
}

class LibraryStorage: SongFileCachable {
    
    static let entitiesToDelete = [Genre.typeName, Artist.typeName, Album.typeName, Song.typeName, SongFile.typeName, Artwork.typeName, SyncWave.typeName, Playlist.typeName, PlaylistItem.typeName, PlayerData.entityName, LogEntry.typeName]

    private let log = OSLog(subsystem: AppDelegate.name, category: "LibraryStorage")
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    var artistCount: Int {
        var count = 0
        do {
            count = try context.count(for: ArtistMO.fetchRequest())
        } catch {}
        return count
    }
    
    var albumCount: Int {
        var count = 0
        do {
            count = try context.count(for: AlbumMO.fetchRequest())
        } catch {}
        return count
    }
    
    var songCount: Int {
        var count = 0
        do {
            count = try context.count(for: SongMO.fetchRequest())
        } catch {}
        return count
    }
    
    var cachedSongCount: Int {
        var count = 0
        let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        request.predicate = NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
        do {
            count = try context.count(for: request)
        } catch {}
        return count
    }
    
    var playlistCount: Int {
        var count = 0
        let request: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        request.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        do {
            count = try context.count(for: request)
        } catch {}
        return count
    }
    
    var cachedSongSizeInKB: Int {
        var foundSongFiles = [NSDictionary]()
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: SongFile.typeName)
        fetchRequest.propertiesToFetch = [#keyPath(SongFileMO.data)]
        fetchRequest.resultType = .dictionaryResultType
        do {
            foundSongFiles = try context.fetch(fetchRequest)
        } catch {}
        
        var cachedSongSizeInKB = 0
        for songFile in foundSongFiles {
            if let fileData = songFile[#keyPath(SongFileMO.data)] as? NSData {
                cachedSongSizeInKB += fileData.sizeInKB
            }
        }
        return cachedSongSizeInKB
    }
    
    func createGenre() -> Genre {
        let genreMO = GenreMO(context: context)
        return Genre(managedObject: genreMO)
    }
    
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
    
    func createLogEntry() -> LogEntry {
        let logEntryMO = LogEntryMO(context: context)
        logEntryMO.creationDate = Date()
        return LogEntry(managedObject: logEntryMO)
    }
    
    func deleteSongFile(songFile: SongFile) {
        context.delete(songFile.managedObject)
    }

    func deleteCache(ofSong song: Song) {
        if let songFile = getSongFile(forSong: song) {
            deleteSongFile(songFile: songFile)
            song.managedObject.file = nil
        }
    }

    func deleteCache(ofPlaylist playlist: Playlist) {
        for song in playlist.songs {
            if let songFile = getSongFile(forSong: song) {
                deleteSongFile(songFile: songFile)
                song.managedObject.file = nil
            }
        }
    }
    
    func deleteCache(ofGenre genre: Genre) {
        for song in genre.songs {
            if let songFile = getSongFile(forSong: song) {
                deleteSongFile(songFile: songFile)
                song.managedObject.file = nil
            }
        }
    }
    
    func deleteCache(ofArtist artist: Artist) {
        for song in artist.songs {
            if let songFile = getSongFile(forSong: song) {
                deleteSongFile(songFile: songFile)
                song.managedObject.file = nil
            }
        }
    }
    
    func deleteCache(ofAlbum album: Album) {
        for song in album.songs {
            if let songFile = getSongFile(forSong: song) {
                deleteSongFile(songFile: songFile)
                song.managedObject.file = nil
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
    
    func deleteSyncWave(item: SyncWave) {
        context.delete(item.managedObject)
    }

    func createSyncWave() -> SyncWave {
        let syncWaveCount = Int16(getSyncWaves().count)
        let syncWaveMO = SyncWaveMO(context: context)
        syncWaveMO.id = syncWaveCount
        return SyncWave(managedObject: syncWaveMO)
    }
    
    func getFetchPredicate(forSyncWave syncWave: SyncWave) -> NSPredicate {
        return NSPredicate(format: "(syncInfo == %@)", syncWave.managedObject.objectID)
    }
    
    func getFetchPredicate(forGenre genre: Genre) -> NSPredicate {
        return NSPredicate(format: "genre == %@", genre.managedObject.objectID)
    }
    
    func getFetchPredicate(forArtist artist: Artist) -> NSPredicate {
        return NSPredicate(format: "artist == %@", artist.managedObject.objectID)
    }
    
    func getFetchPredicate(forAlbum album: Album) -> NSPredicate {
        return NSPredicate(format: "album == %@", album.managedObject.objectID)
    }
    
    func getFetchPredicate(forPlaylist playlist: Playlist) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(PlaylistItemMO.playlist), playlist.managedObject.objectID)
    }
    
    func getFetchPredicate(onlyCachedSongs: Bool) -> NSPredicate {
        if onlyCachedSongs {
            return NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(forPlaylistSearchCategory playlistSearchCategory: PlaylistSearchCategory) -> NSPredicate {
        switch playlistSearchCategory {
        case .all:
            return NSPredicate.alwaysTrue
        case .userOnly:
            return NSPredicate(format: "NOT (%K BEGINSWITH %@)", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        case .smartOnly:
            return NSPredicate(format: "%K BEGINSWITH %@", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        }
    }

    func getArtists() -> Array<Artist> {
        var artists = Array<Artist>()
        var foundArtists = Array<ArtistMO>()
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        do {
            foundArtists = try context.fetch(fetchRequest)
            for artistMO in foundArtists {
                artists.append(Artist(managedObject: artistMO))
            }
        } catch {}
        
        return artists
    }
    
    func getAlbums() -> Array<Album> {
        var albums = Array<Album>()
        var foundAlbums = Array<AlbumMO>()
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        do {
            foundAlbums = try context.fetch(fetchRequest)
            for albumMO in foundAlbums {
                albums.append(Album(managedObject: albumMO))
            }
        } catch {}
        
        return albums
    }

    func getSongs() -> Array<Song> {
        var songs = Array<Song>()
        var foundSongs = Array<SongMO>()
        let fetchRequest = SongMO.identifierSortedFetchRequest
        do {
            foundSongs = try context.fetch(fetchRequest)
            for songMO in foundSongs {
                songs.append(Song(managedObject: songMO))
            }
        } catch {}
        
        return songs
    }
    
    func getPlaylists() -> Array<Playlist> {
        var playlists = Array<Playlist>()
        var foundPlaylists = Array<PlaylistMO>()
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        do {
            foundPlaylists = try context.fetch(fetchRequest)
            for playlist in foundPlaylists {
                let wrappedPlaylist = Playlist(storage: self, managedObject: playlist)
                playlists.append(wrappedPlaylist)
            }
        } catch {}
        
        return playlists
    }
    
    func getLogEntries() -> Array<LogEntry> {
        var entries = Array<LogEntry>()
        var foundEntries = Array<LogEntryMO>()
        let fetchRequest: NSFetchRequest<LogEntryMO> = LogEntryMO.creationDateSortedFetchRequest
        do {
            foundEntries = try context.fetch(fetchRequest)
            entries = foundEntries.compactMap{ LogEntry(managedObject: $0) }
        } catch {}
        return entries
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
    
    func getGenre(id: String) -> Genre? {
        var foundGenre: Genre? = nil
        let fr: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.id), NSString(string: id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let genres = result, genres.count > 0, let genre = genres[0] as? GenreMO {
                foundGenre = Genre(managedObject: genre)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundGenre
    }
    
    func getGenre(name: String) -> Genre? {
        var foundGenre: Genre? = nil
        let fr: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.name), NSString(string: name))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let genres = result, genres.count > 0, let genre = genres[0] as? GenreMO {
                foundGenre = Genre(managedObject: genre)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundGenre
    }
    
    func getArtist(id: String) -> Artist? {
        var foundArtist: Artist? = nil
        let fr: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), NSString(string: id))
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
    
    func getAlbum(id: String) -> Album? {
        var foundAlbum: Album? = nil
        let fr: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(AlbumMO.id), NSString(string: id))
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
    
    func getSong(id: String) -> Song? {
        var foundSong: Song? = nil
        let fr: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(SongMO.id), NSString(string: id))
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
    
    func getSongFile(forSong song: Song) -> SongFile? {
        guard song.isCached else { return nil }
        var foundSongFile: SongFile? = nil
        let fr: NSFetchRequest<SongFileMO> = SongFileMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(SongFileMO.info.id), NSString(string: song.id))
        fr.fetchLimit = 1
        do {
            let result = try context.fetch(fr) as NSArray?
            if let songFiles = result, songFiles.count > 0, let songFile = songFiles[0] as? SongFileMO  {
                foundSongFile = SongFile(managedObject: songFile)
            }
        } catch {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
        return foundSongFile
    }

    func getPlaylist(id: String) -> Playlist? {
        var foundPlaylist: Playlist? = nil
        let fr: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(PlaylistMO.id), NSString(string: id))
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
        fr.predicate = NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue)))
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
        fr.predicate = NSPredicate(format: "%K == max(%K)", #keyPath(SyncWaveMO.id), #keyPath(SyncWaveMO.id))
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
