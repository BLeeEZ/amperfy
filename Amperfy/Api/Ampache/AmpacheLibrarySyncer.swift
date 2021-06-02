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
    var genreCount: Int {
        return ampacheXmlServerApi.genreCount
    }
    var playlistCount: Int {
        return ampacheXmlServerApi.playlistCount
    }
    
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
        
        statusNotifyier?.notifySyncStarted(ofType: .genre)
        let genreParser = GenreParserDelegate(libraryStorage: currentLibraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
        self.ampacheXmlServerApi.requestGenres(parserDelegate: genreParser)
        currentLibraryStorage.saveContext()

        statusNotifyier?.notifySyncStarted(ofType: .artist)
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

        statusNotifyier?.notifySyncStarted(ofType: .album)
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
        
        statusNotifyier?.notifySyncStarted(ofType: .playlist)
        let playlistParser = PlaylistParserDelegate(libraryStorage: currentLibraryStorage, parseNotifier: statusNotifyier)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
        currentLibraryStorage.saveContext()
                
        syncWave.syncState = .Done
        currentLibraryStorage.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    func sync(artist: Artist, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        let albumParser = AlbumParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestArtistAlbums(of: artist, parserDelegate: albumParser)
        let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestArtistSongs(of: artist, parserDelegate: songParser)
        libraryStorage.saveContext()
    }
    
    func sync(album: Album, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        let songParser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestAlbumSongs(of: album, parserDelegate: songParser)
        libraryStorage.saveContext()
    }
    
    func syncMusicFolders(libraryStorage: LibraryStorage) {
        ampacheXmlServerApi.eventLogger.error(topic: "Internal Error", statusCode: .internalError, message: "GetMusicFolders API function is not support by Ampache")
    }
    
    func syncIndexes(musicFolder: MusicFolder, libraryStorage: LibraryStorage) {
        ampacheXmlServerApi.eventLogger.error(topic: "Internal Error", statusCode: .internalError, message: "GetIndexes API function is not support by Ampache")
    }
    
    func sync(directory: Directory, libraryStorage: LibraryStorage) {
        ampacheXmlServerApi.eventLogger.error(topic: "Internal Error", statusCode: .internalError, message: "GetMusicDirectory API function is not support by Ampache")
    }

    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage, parseNotifier: nil)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { return }
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        guard playlist.id != "" else { return }

        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        let parser = PlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage, syncWave: syncWave)
        ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        libraryStorage.saveContext()
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], libraryStorage: LibraryStorage) {
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        validatePlaylistId(playlist: playlist, libraryStorage: libraryStorage)
        for song in songs {
            ampacheXmlServerApi.requestPlaylistAddSong(playlist: playlist, song: song)
        }
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, libraryStorage: LibraryStorage) {
        os_log("Upload SongDelete on playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistDeleteItem(playlist: playlist, index: index)
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist, libraryStorage: LibraryStorage) {
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistEdit(playlist: playlist)
    }
    
    func syncUpload(playlistToDelete playlist: Playlist) {
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistDelete(playlist: playlist)
    }
    
    private func validatePlaylistId(playlist: Playlist, libraryStorage: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage, parseNotifier: nil)
        playlistParser.playlist = playlist
        ampacheXmlServerApi.requestPlaylist(parserDelegate: playlistParser, id: playlist.id)
        if playlist.id == "" {
            os_log("Create playlist on server", log: log, type: .info)
            let playlistParser = PlaylistParserDelegate(libraryStorage: libraryStorage, parseNotifier: nil)
            playlistParser.playlist = playlist
            ampacheXmlServerApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        }
    }
    
    func searchSongs(searchText: String, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave)
        ampacheXmlServerApi.requestSearchSongs(parserDelegate: parser, searchText: searchText)
        libraryStorage.saveContext()
    }

}
