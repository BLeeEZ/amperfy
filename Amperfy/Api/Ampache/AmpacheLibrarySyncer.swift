import Foundation
import CoreData
import os.log

class AmpacheLibrarySyncer: GenericLibrarySyncer, LibrarySyncer {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    
    var artistCount: Int {
        return ampacheXmlServerApi.artistCount
    }
    var albumCount: Int {
        return ampacheXmlServerApi.albumCount
    }
    var songCount: Int {
        return ampacheXmlServerApi.songCount
    }
    
    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    func sync(libraryStorage: LibraryStorage, statusNotifyier: SyncCallbacks? = nil) {
        if let libMetaData = ampacheXmlServerApi.requesetLibraryMetaData() {
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: libMetaData.libraryChangeDates)

            statusNotifyier?.notifyArtistSyncStarted()
            let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, ampacheUrlCreator: ampacheXmlServerApi, parseNotifier: statusNotifyier)
            ampacheXmlServerApi.requestArtists(parserDelegate: artistParser)
            addInstForUnknownArtitst(libraryStorage: libraryStorage)
            
            statusNotifyier?.notifyAlbumsSyncStarted()
            let albumDelegate = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
            ampacheXmlServerApi.requestAlbums(parserDelegate: albumDelegate)
            
            statusNotifyier?.notifySongsSyncStarted()
            let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
            ampacheXmlServerApi.requestSongs(parserDelegate: songParser)
            
            statusNotifyier?.notifyPlaylistSyncStarted()
            let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
            ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
            statusNotifyier?.notifyPlaylistCount(playlistCount: libraryStorage.getPlaylists().count)
            // Request the songs in all playlists
            for playlist in libraryStorage.getPlaylists() {
                playlist.removeAllSongs()
                let parser = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
                ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
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
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
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
        ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
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
            ampacheXmlServerApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        }
        
        os_log("Request playlist songs from remote for following clear request", log: log, type: .info)
        let playlistForRemoteClear = libraryStorage.createPlaylist()
        let parser = PlaylistSongsParserDelegate(playlist: playlistForRemoteClear, libraryStorage: libraryStorage)
        ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        os_log("Clear remote playlist songs", log: log, type: .info)
        for entry in playlistForRemoteClear.entries {
            ampacheXmlServerApi.requestPlaylist(removeSongIndex: entry.order, fromPlaylistId: playlist.id)
        }
        libraryStorage.deletePlaylist(playlistForRemoteClear)
        
        os_log("Uploading playlist songs", log: log, type: .info)
        for song in playlist.songs {
            ampacheXmlServerApi.requestPlaylist(addSongId: song.id, toPlaylistId: playlist.id)
        }
        statusNotifyier?.notifyPlaylistUploadFinished(success: true)
    }
    
    private func validatePlaylistId(playlist: Playlist, libraryStorage: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
        playlistParser.playlist = playlist
        ampacheXmlServerApi.requestPlaylist(parserDelegate: playlistParser, id: playlist.id)
    }
    
    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        if let latestSyncWave = libraryStorage.getLatestSyncWave(), !latestSyncWave.isDone {
            os_log("Lib resync: Continue last resync", log: log, type: .info)
            resync(libraryStorage: libraryStorage, syncWave: latestSyncWave, previousAddDate: latestSyncWave.libraryChangeDates.dateOfLastAdd)
        } else if let latestSyncWave = libraryStorage.getLatestSyncWave(),
        let ampacheMetaData = ampacheXmlServerApi.requesetLibraryMetaData(),
        latestSyncWave.libraryChangeDates.dateOfLastAdd != ampacheMetaData.libraryChangeDates.dateOfLastAdd {
            os_log("Lib resync: New changes on server", log: log, type: .info)
            let syncWave = libraryStorage.createSyncWave()
            syncWave.setMetaData(fromLibraryChangeDates: ampacheMetaData.libraryChangeDates)
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
                let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, ampacheUrlCreator: ampacheXmlServerApi)
                ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
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
                ampacheXmlServerApi.requestAlbums(parserDelegate: albumParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
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
                ampacheXmlServerApi.requestSongs(parserDelegate: songParser, addDate: addDate, startIndex: syncWave.syncIndexToContinue, pollCount: AmpacheXmlServerApi.maxItemCountToPollAtOnce)
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

}
