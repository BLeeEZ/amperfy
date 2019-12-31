import Foundation
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
    
    func sync(libraryStorage: LibraryStorage, statusNotifyier: SyncCallbacks?) {
        let syncWave = libraryStorage.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
        
        statusNotifyier?.notifyArtistSyncStarted()
        let artistParser = SsArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
        subsonicServerApi.requestArtists(parserDelegate: artistParser)
        albumCount = artistParser.albumCountOfAllArtists
        addInstForUnknownArtitst(libraryStorage: libraryStorage)
        
        statusNotifyier?.notifyAlbumsSyncStarted()
        let artists = libraryStorage.getArtists()
        for artist in artists {
            let albumDelegate = SsAlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
            subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artist.id)
            songCount += albumDelegate.songCountOfAlbum
        }

        statusNotifyier?.notifySongsSyncStarted()
        let albums = libraryStorage.getAlbums()
        for album in albums {
            let songDelegate = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
            subsonicServerApi.requestAlbum(parserDelegate: songDelegate, id: album.id)
        }
        
        statusNotifyier?.notifyPlaylistSyncStarted()
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        playlistCount = libraryStorage.getPlaylists().count
        statusNotifyier?.notifyPlaylistSyncStarted()
        // Request the songs in all playlists
        for playlist in libraryStorage.getPlaylists() {
            playlist.removeAllSongs()
            let parser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
            subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
            statusNotifyier?.notifyParsedObject()
        }
        
        syncWave.syncState = .Done
        libraryStorage.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    private func addInstForUnknownArtitst(libraryStorage: LibraryStorage) {
        let unknownArtist = libraryStorage.createArtist()
        unknownArtist.id = 0
        unknownArtist.name = "Unknown Artist"
    }
    
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage) {
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?) {
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != 0 else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }
        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        statusNotifyier?.notifyPlaylistWillCleared()
        playlist.removeAllSongs()
        let parser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        libraryStorage.saveContext()
        statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist)
    }
    
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks?) {
        os_log("Upload playlist \"%s\" to server", log: log, type: .info, playlist.name)
        if playlist.id == 0 {
            createPlaylistRemote(playlist: playlist, libraryStorage: libraryStorage)
        }
        guard playlist.id != 0 else {
            os_log("Playlist id could not be obtained", log: log, type: .info)
            return
        }

        os_log("Request playlist songs from remote for following clear request", log: log, type: .info)
        let playlistForRemoteClear = libraryStorage.createPlaylist()
        var parser = SsPlaylistSongsParserDelegate(playlist: playlistForRemoteClear, libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        
        if !parser.playlistHasBeenDetected {
            playlist.id = 0
            createPlaylistRemote(playlist: playlist, libraryStorage: libraryStorage)
            guard playlist.id != 0 else {
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

        var songIdsToAdd = [Int]()
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
        if playlist.id == 0 {
            updatePlaylistIdViaItsName(playlist: playlist, libraryStorage: libraryStorage)
        }
    }

    private func updatePlaylistIdViaItsName(playlist: Playlist, libraryStorage: LibraryStorage) {
        syncDownPlaylistsWithoutSongs(libraryStorage: libraryStorage)
        let playlists = libraryStorage.getPlaylists()
        let nameMatchingPlaylists = playlists.filter{ filterPlaylist in
            if filterPlaylist.name == playlist.name, filterPlaylist.id != 0 {
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
