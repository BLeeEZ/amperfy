import Foundation
import CoreData
import os.log

class SubsonicLibrarySyncer: LibrarySyncer {

    private let subsonicServerApi: SubsonicServerApi
    private let log = OSLog(subsystem: AppDelegate.name, category: "SubsonicLibSyncer")
    
    public private(set) var artistCount: Int = 0
    public private(set) var albumCount: Int = 1
    public private(set) var songCount: Int = 1
    public private(set) var playlistCount: Int = 1
    
    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?) {
        let downloadSlotCounter = DownloadSlotCounter(maximumActiveDownloads: 5)
        let currentLibraryStorage = LibraryStorage(context: currentContext)

        let syncWave = currentLibraryStorage.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
        currentLibraryStorage.saveContext()
        
        let genreParser = SsGenreParserDelegate(libraryStorage: currentLibraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
        subsonicServerApi.requestGenres(parserDelegate: genreParser)
        currentLibraryStorage.saveContext()
        
        statusNotifyier?.notifyArtistSyncStarted()
        let artistParser = SsArtistParserDelegate(libraryStorage: currentLibraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
        subsonicServerApi.requestArtists(parserDelegate: artistParser)
        currentLibraryStorage.saveContext()
         
        let artists = currentLibraryStorage.getArtists()
        albumCount = artists.count
        statusNotifyier?.notifyAlbumsSyncStarted()
        for artist in artists {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let artistMO = try! context.existingObject(with: artist.managedObject.objectID) as! ArtistMO
                let artistContext = Artist(managedObject: artistMO)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let albumDelegate = SsAlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWaveContext, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                self.subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artistContext.id)
                libraryStorage.saveContext()
                statusNotifyier?.notifyParsedObject()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()

        let albums = currentLibraryStorage.getAlbums()
        songCount = albums.count
        statusNotifyier?.notifySongsSyncStarted()
        for album in albums {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let albumMO = try! context.existingObject(with: album.managedObject.objectID) as! AlbumMO
                let albumContext = Album(managedObject: albumMO)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let songDelegate = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWaveContext, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                songDelegate.guessedArtist = albumContext.artist
                songDelegate.guessedAlbum = albumContext
                songDelegate.guessedGenre = albumContext.genre
                self.subsonicServerApi.requestAlbum(parserDelegate: songDelegate, id: albumContext.id)
                libraryStorage.saveContext()
                statusNotifyier?.notifyParsedObject()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()

        statusNotifyier?.notifyPlaylistSyncStarted()
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: currentLibraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        currentLibraryStorage.saveContext()
        
        let playlists = currentLibraryStorage.getPlaylists()
        playlistCount = playlists.count
        statusNotifyier?.notifyPlaylistSyncStarted()
        for playlist in playlists {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let playlistMO = try! context.existingObject(with: playlist.managedObject.objectID) as! PlaylistMO
                let playlistContext = Playlist(storage: libraryStorage, managedObject: playlistMO)
                playlistContext.removeAllSongs()
                let parser = SsPlaylistSongsParserDelegate(playlist: playlistContext, libraryStorage: libraryStorage)
                self.subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlistContext.id)
                playlist.ensureConsistentItemOrder()
                libraryStorage.saveContext()
                statusNotifyier?.notifyParsedObject()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()
        
        syncWave.syncState = .Done
        currentLibraryStorage.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage) {
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?) {
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }
        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        statusNotifyier?.notifyPlaylistWillCleared()
        playlist.removeAllSongs()
        let parser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        libraryStorage.saveContext()
        statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist)
    }
    
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?) {
        os_log("Upload playlist \"%s\" to server", log: log, type: .info, playlist.name)
        if playlist.id == "" {
            createPlaylistRemote(playlist: playlist, libraryStorage: libraryStorage)
        }
        guard playlist.id != "" else {
            os_log("Playlist id could not be obtained", log: log, type: .info)
            return
        }

        os_log("Request playlist songs from remote for following clear request", log: log, type: .info)
        let playlistForRemoteClear = libraryStorage.createPlaylist()
        var parser = SsPlaylistSongsParserDelegate(playlist: playlistForRemoteClear, libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        
        if !parser.playlistHasBeenDetected {
            playlist.id = ""
            createPlaylistRemote(playlist: playlist, libraryStorage: libraryStorage)
            guard playlist.id != "" else {
                os_log("Playlist id could not be obtained", log: log, type: .info)
                return
            }
            parser = SsPlaylistSongsParserDelegate(playlist: playlistForRemoteClear, libraryStorage: libraryStorage)
            subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        }
        
        guard parser.playlistHasBeenDetected else {
            os_log("Playlist songs could not be obtained", log: log, type: .info)
            return
        }

        os_log("Update remote playlist songs", log: log, type: .info)
        var songIndicesToRemove = [Int]()
        for item in playlistForRemoteClear.items {
            songIndicesToRemove.append(item.order)
        }

        var songIdsToAdd = [String]()
        for item in playlist.items {
            if let songItem = item.song {
                songIdsToAdd.append(songItem.id)
            }
        }

        let updateResponseParser = PingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)

        libraryStorage.deletePlaylist(playlistForRemoteClear)
        libraryStorage.saveContext()
        statusNotifyier?.notifyPlaylistUploadFinished(success: true)
    }
    
    private func createPlaylistRemote(playlist: Playlist, libraryStorage: LibraryStorage) {
        os_log("Create playlist on server", log: log, type: .info)
        let playlistParser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        // Old api version -> need to match the created playlist via name
        if playlist.id == "" {
            updatePlaylistIdViaItsName(playlist: playlist, libraryStorage: libraryStorage)
        }
    }

    private func updatePlaylistIdViaItsName(playlist: Playlist, libraryStorage: LibraryStorage) {
        syncDownPlaylistsWithoutSongs(libraryStorage: libraryStorage)
        let playlists = libraryStorage.getPlaylists()
        let nameMatchingPlaylists = playlists.filter{ filterPlaylist in
            if filterPlaylist.name == playlist.name, filterPlaylist.id != "" {
                return true
            }
            return false
        }
        guard !nameMatchingPlaylists.isEmpty, let firstMatch = nameMatchingPlaylists.first else { return }
        let matchedId = firstMatch.id
        libraryStorage.deletePlaylist(firstMatch)
        playlist.id = matchedId
    }
    
}
