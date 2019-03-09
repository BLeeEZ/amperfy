import Foundation
import CoreData
import os.log

protocol ParsedObjectNotifiable {
    func notifyParsedObject()
}

protocol SyncCallbacks: ParsedObjectNotifiable {
    func notifyArtistSyncStarted()
    func notifyAlbumsSyncStarted()
    func notifySongsSyncStarted()
    func notifyPlaylistSyncStarted()
    func notifyPlaylistCount(playlistCount: Int)
    func notifySyncFinished()
}

protocol PlaylistSyncCallbacks {
    func notifyPlaylistWillCleared()
    func notifyPlaylistSyncFinished(playlist: Playlist)
    func notifyPlaylistUploadFinished(success: Bool)
}

class LibrarySyncer {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "librarySyncer")
    var ampacheApi: AmpacheApi
    private let semaphoreGroup = DispatchGroup()
    private var isRunning = false
    public private(set) var isActive = false
    
    init(ampacheApi: AmpacheApi) {
        self.ampacheApi = ampacheApi
    }
    
    func sync(libraryStorage: LibraryStorage, statusNotifyier: SyncCallbacks? = nil) {
        if let libMetaData = ampacheApi.requesetLibraryMetaData() {
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromAuth: libMetaData)

            statusNotifyier?.notifyArtistSyncStarted()
            let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, ampacheUrlCreator: ampacheApi, parseNotifier: statusNotifyier)
            ampacheApi.requestArtists(parserDelegate: artistParser)
            addInstForUnknownArtitst(libraryStorage: libraryStorage)
            
            statusNotifyier?.notifyAlbumsSyncStarted()
            let albumDelegate = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
            ampacheApi.requestAlbums(parserDelegate: albumDelegate)
            
            statusNotifyier?.notifySongsSyncStarted()
            let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
            ampacheApi.requestSongs(parserDelegate: songParser)
            
            statusNotifyier?.notifyPlaylistSyncStarted()
            let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
            ampacheApi.requestPlaylists(parserDelegate: playlistParser)
            statusNotifyier?.notifyPlaylistCount(playlistCount: libraryStorage.getPlaylists().count)
            // Request the songs in all playlists
            for playlist in libraryStorage.getPlaylists() {
                playlist.removeAllSongs()
                let parser = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
                ampacheApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
                statusNotifyier?.notifyParsedObject()
            }
        
            syncWave.syncState = .Done
            libraryStorage.saveContext()
            statusNotifyier?.notifySyncFinished()
        }
    }
    
    private func addInstForUnknownArtitst(libraryStorage: LibraryStorage) {
        let unknownArtist = libraryStorage.createArtist()
        unknownArtist.id = 0
        unknownArtist.name = "Unknown Artist"
    }
    
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
        ampacheApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks? = nil) {
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != 0 else { return }
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        guard playlist.id != 0 else { return }

        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        statusNotifyier?.notifyPlaylistWillCleared()
        playlist.removeAllSongs()
        let parser = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
        ampacheApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        libraryStorage.saveContext()
        statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist)
    }
    
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks? = nil) {
        os_log("Upload playlist \"%s\" to server", log: log, type: .info, playlist.name)
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        if playlist.id == 0 {
            os_log("Create playlist on server", log: log, type: .info)
            let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
            playlistParser.playlist = playlist
            ampacheApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        }
        
        os_log("Request playlist songs from remote for following clear request", log: log, type: .info)
        let playlistForRemoteClear = libraryStorage.createPlaylist()
        let parser = PlaylistSongsParserDelegate(playlist: playlistForRemoteClear, libraryStorage: libraryStorage)
        ampacheApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        os_log("Clear remote playlist songs", log: log, type: .info)
        for entry in playlistForRemoteClear.entries {
            ampacheApi.requestPlaylist(removeSongIndex: entry.order, fromPlaylistId: playlist.id)
        }
        libraryStorage.deletePlaylist(playlistForRemoteClear)
        
        os_log("Uploading playlist songs", log: log, type: .info)
        for song in playlist.songs {
            ampacheApi.requestPlaylist(addSongId: song.id, toPlaylistId: playlist.id)
        }
        statusNotifyier?.notifyPlaylistUploadFinished(success: true)
    }
    
    private func validatePlaylistId(playlist: Playlist, libraryStorage: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
        playlistParser.playlist = playlist
        ampacheApi.requestPlaylist(parserDelegate: playlistParser, id: playlist.id)
    }
    
    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        if let latestSyncWave = libraryStorage.getLatestSyncWave(), !latestSyncWave.isDone {
            os_log("Lib resync: Continue last resync", log: log, type: .info)
            resync(libraryStorage: libraryStorage, syncWave: latestSyncWave, previousAddDate: latestSyncWave.libraryChangeDates.dateOfLastAdd)
        } else if let latestSyncWave = libraryStorage.getLatestSyncWave(),
        let ampacheMetaData = ampacheApi.requesetLibraryMetaData(),
        latestSyncWave.libraryChangeDates.dateOfLastAdd != ampacheMetaData.libraryChangeDates.dateOfLastAdd {
            os_log("Lib resync: New changes on server", log: log, type: .info)
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromAuth: ampacheMetaData)
            libraryStorage.saveContext()
            resync(libraryStorage: libraryStorage, syncWave: syncWave, previousAddDate: latestSyncWave.libraryChangeDates.dateOfLastAdd)
        } else {
            os_log("Lib resync: No changes", log: log, type: .info)
        }
        isActive = false
        semaphoreGroup.leave()
    }   
    
    func resync(libraryStorage: LibraryStorage, syncWave: SyncWaveMO, previousAddDate: Date) {
        // Add one second to previouseAddDate to avoid resyncing previous sync Wave
        let addDate = Date(timeInterval: 1, since: previousAddDate)

        if syncWave.syncState == .Artists, isRunning {
            var allParsed = false
            repeat {
                let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, ampacheUrlCreator: ampacheApi)
                ampacheApi.requestArtists(parserDelegate: artistParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheApi.maxItemCountToPollAtOnce)
                syncWave.syncIndexToContinue += artistParser.parsedCount
                allParsed = artistParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib resync: %d Artists parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Albums
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Albums, isRunning {
            var allParsed = false
            repeat {
                let albumParser = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave)
                ampacheApi.requestAlbums(parserDelegate: albumParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheApi.maxItemCountToPollAtOnce)
                syncWave.syncIndexToContinue += albumParser.parsedCount
                allParsed = albumParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib resync: %d Albums parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Songs
            }
            libraryStorage.saveContext()
        }
        if syncWave.syncState == .Songs, isRunning {
            var allParsed = false
            repeat {
                let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave)
                ampacheApi.requestSongs(parserDelegate: songParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheApi.maxItemCountToPollAtOnce)
                syncWave.syncIndexToContinue += songParser.parsedCount
                allParsed = songParser.parsedCount == 0
            } while(!allParsed && isRunning)

            if allParsed {
                os_log("Lib resync: %d Songs parsed", log: log, type: .info, syncWave.syncIndexToContinue)
                syncWave.syncState = .Done
            }
            libraryStorage.saveContext()
        }
    }
    
    func stop() {
        isRunning = false
    }

    func stopAndWait() {
        stop()
        semaphoreGroup.wait()
    }

}
