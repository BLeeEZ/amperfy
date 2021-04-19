import Foundation
import CoreData
import os.log
import UIKit

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
    
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks? = nil) {
        guard let libMetaData = ampacheXmlServerApi.requesetLibraryMetaData() else { return }
        
        let downloadSlotCounter = DownloadSlotCounter(maximumActiveDownloads: 5)
        let currentLibraryStorage = LibraryStorage(context: currentContext)

        let syncWave = currentLibraryStorage.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: libMetaData.libraryChangeDates)
        currentLibraryStorage.saveContext()

        statusNotifyier?.notifyArtistSyncStarted()
        let pollCountArtist = (ampacheXmlServerApi.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCountArtist {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let artistParser = ArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWaveContext, ampacheUrlCreator: self.ampacheXmlServerApi, parseNotifier: statusNotifyier)
                self.ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                libraryStorage.saveContext()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()

        statusNotifyier?.notifyAlbumsSyncStarted()
        let pollCountAlbum = (ampacheXmlServerApi.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCountAlbum {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let albumDelegate = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWaveContext, parseNotifier: statusNotifyier)
                self.ampacheXmlServerApi.requestAlbums(parserDelegate: albumDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                libraryStorage.saveContext()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()
        
        statusNotifyier?.notifySongsSyncStarted()
        let pollCountSong = (ampacheXmlServerApi.songCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCountSong {
            downloadSlotCounter.waitForDownloadSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let libraryStorage = LibraryStorage(context: context)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWaveContext, parseNotifier: statusNotifyier)
                self.ampacheXmlServerApi.requestSongs(parserDelegate: songParser, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                libraryStorage.saveContext()
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()
        
        let playlistParser = PlaylistParserDelegate(libraryStorage: currentLibraryStorage)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
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
                let parser = PlaylistSongsParserDelegate(playlist: playlistContext, libraryStorage: libraryStorage)
                self.ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlistContext.id)
                playlistContext.ensureConsistentItemOrder()
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
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks? = nil) {
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        guard playlist.id != "" else { statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist); return }

        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        statusNotifyier?.notifyPlaylistWillCleared()
        playlist.removeAllSongs()
        let parser = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage)
        ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        libraryStorage.saveContext()
        statusNotifyier?.notifyPlaylistSyncFinished(playlist: playlist)
    }
    
    func syncUpload(playlist: Playlist, libraryStorage: LibraryStorage, statusNotifyier: PlaylistSyncCallbacks? = nil) {
        os_log("Upload playlist \"%s\" to server", log: log, type: .info, playlist.name)
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        if playlist.id == "" {
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
