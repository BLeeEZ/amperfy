import Foundation
import CoreData
import os.log

class AmpacheLibrarySyncer: LibrarySyncer {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private let log = OSLog(subsystem: AppDelegate.name, category: "AmpacheLibSyncer")
    
    var artistCount: Int {
        return ampacheXmlServerApi.artistCount
    }
    var albumCount: Int {
        return ampacheXmlServerApi.albumCount
    }
    var songCount: Int {
        return ampacheXmlServerApi.songCount
    }
    public private(set) var playlistCount: Int = 1
    
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
            
            let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
            ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
            playlistCount = libraryStorage.getPlaylists().count
            statusNotifyier?.notifyPlaylistSyncStarted()
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
        guard playlist.id != 0 else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        guard playlist.id != 0 else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }

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
        for item in playlistForRemoteClear.items.reversed() {
            ampacheXmlServerApi.requestPlaylist(removeSongIndex: item.order, fromPlaylistId: playlist.id)
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

}
