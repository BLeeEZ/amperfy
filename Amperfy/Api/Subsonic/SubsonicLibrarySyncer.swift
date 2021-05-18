import Foundation
import CoreData
import os.log

class SubsonicLibrarySyncer: LibrarySyncer {

    private let subsonicServerApi: SubsonicServerApi
    private let log = OSLog(subsystem: AppDelegate.name, category: "SubsonicLibSyncer")
    
    public private(set) var artistCount: Int = 0
    public private(set) var albumCount: Int = 1
    public private(set) var songCount: Int = 1
    public private(set) var genreCount: Int = 1
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
        
        statusNotifyier?.notifySyncStarted(ofType: .genre)
        let genreParser = SsGenreParserDelegate(libraryStorage: currentLibraryStorage, syncWave: syncWave, parseNotifier: statusNotifyier)
        subsonicServerApi.requestGenres(parserDelegate: genreParser)
        currentLibraryStorage.saveContext()
        
        statusNotifyier?.notifySyncStarted(ofType: .artist)
        let artistParser = SsArtistParserDelegate(libraryStorage: currentLibraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
        subsonicServerApi.requestArtists(parserDelegate: artistParser)
        currentLibraryStorage.saveContext()
         
        let artists = currentLibraryStorage.getArtists()
        albumCount = artists.count
        statusNotifyier?.notifySyncStarted(ofType: .album)
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
                statusNotifyier?.notifyParsedObject(ofType: .album)
                downloadSlotCounter.downloadFinished()
            }
        }
        downloadSlotCounter.waitTillAllDownloadsFinished()
        
        statusNotifyier?.notifySyncStarted(ofType: .playlist)
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: currentLibraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        currentLibraryStorage.saveContext()

        syncWave.syncState = .Done
        currentLibraryStorage.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    func sync(artist: Artist, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        let artistParser = SsArtistParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestArtist(parserDelegate: artistParser, id: artist.id)
        for album in artist.albums {
            let songParser = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestAlbum(parserDelegate: songParser, id: album.id)
        }
        libraryStorage.saveContext()
    }
    
    func sync(album: Album, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        let songParser = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestAlbum(parserDelegate: songParser, id: album.id)
        libraryStorage.saveContext()
    }
    
    func syncDownPlaylistsWithoutSongs(libraryStorage: LibraryStorage) {
        let playlistParser = SsPlaylistParserDelegate(libraryStorage: libraryStorage)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        libraryStorage.saveContext()
    }
    
    func syncDown(playlist: Playlist, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { return }
        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        let parser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        libraryStorage.saveContext()
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave() else { return }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        if playlist.id == "" {
            createPlaylistRemote(playlist: playlist, libraryStorage: libraryStorage, syncWave: syncWave)
        }
        guard playlist.id != "" else {
            os_log("Playlist id could not be obtained", log: log, type: .info)
            return
        }
        
        let songIdsToAdd = songs.compactMap{ $0.id }
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: [], songIdsToAdd: songIdsToAdd)
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, libraryStorage: LibraryStorage) {
        os_log("Upload SongDelete on playlist \"%s\"", log: log, type: .info, playlist.name)
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: [index], songIdsToAdd: [])
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist, libraryStorage: LibraryStorage) {
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        let songIndicesToRemove = Array(0...playlist.songCount-1)
        let songIdsToAdd = playlist.songs.compactMap{ $0.id }
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)
    }
    
    func syncUpload(playlistToDelete playlist: Playlist) {
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, playlist.name)
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistDelete(parserDelegate: updateResponseParser, playlist: playlist)
    }
    
    func searchSongs(searchText: String, libraryStorage: LibraryStorage) {
        guard let syncWave = libraryStorage.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SsSongParserDelegate(libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestSearchSongs(parserDelegate: parser, searchText: searchText)
        libraryStorage.saveContext()
    }
    
    private func createPlaylistRemote(playlist: Playlist, libraryStorage: LibraryStorage, syncWave: SyncWave) {
        os_log("Create playlist on server", log: log, type: .info)
        let playlistParser = SsPlaylistSongsParserDelegate(playlist: playlist, libraryStorage: libraryStorage, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
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
