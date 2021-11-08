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
    public private(set) var podcastCount: Int = 1
    
    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks?) {
        let taskGroup = ConcurrentTaskGroup(taskSlotsCount: 5)
        let syncLibrary = LibraryStorage(context: currentContext)

        let syncWave = syncLibrary.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
        syncLibrary.saveContext()

        statusNotifyier?.notifySyncStarted(ofType: .genre)
        let genreParser = SsGenreParserDelegate(library: syncLibrary, syncWave: syncWave, parseNotifier: statusNotifyier)
        subsonicServerApi.requestGenres(parserDelegate: genreParser)
        syncLibrary.saveContext()
        
        statusNotifyier?.notifySyncStarted(ofType: .artist)
        let artistParser = SsArtistParserDelegate(library: syncLibrary, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
        subsonicServerApi.requestArtists(parserDelegate: artistParser)
        syncLibrary.saveContext()
         
        let artists = syncLibrary.getArtists()
        albumCount = artists.count
        statusNotifyier?.notifySyncStarted(ofType: .album)
        let artistBatches = artists.chunked(intoSubarrayCount: taskGroup.maxTaskSlots)
        for artistBatch in artistBatches {
            taskGroup.waitForSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let batchLibrary = LibraryStorage(context: context)
                for artist in artistBatch {
                    let artistMO = try! context.existingObject(with: artist.managedObject.objectID) as! ArtistMO
                    let artistContext = Artist(managedObject: artistMO)
                    let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                    let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                    let albumDelegate = SsAlbumParserDelegate(library: batchLibrary, syncWave: syncWaveContext, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                    albumDelegate.guessedArtist = artistContext
                    self.subsonicServerApi.requestArtist(parserDelegate: albumDelegate, id: artistContext.id)
                    statusNotifyier?.notifyParsedObject(ofType: .album)
                }
                batchLibrary.saveContext()
                taskGroup.taskFinished()
            }
        }
        taskGroup.waitTillAllTasksFinished()
        // Delete duplicated albums due to concurrence
        let albums = syncLibrary.getAlbums()
        var uniqueAlbums: [String: Album] = [:]
        for album in albums {
            if uniqueAlbums[album.id] != nil {
                syncLibrary.deleteAlbum(album: album)
            } else {
                uniqueAlbums[album.id] = album
            }
        }
        
        statusNotifyier?.notifySyncStarted(ofType: .playlist)
        let playlistParser = SsPlaylistParserDelegate(library: syncLibrary)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        syncLibrary.saveContext()
        
        if subsonicServerApi.isPodcastSupported {
            statusNotifyier?.notifySyncStarted(ofType: .podcast)
            let podcastParser = SsPodcastParserDelegate(library: syncLibrary, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi, parseNotifier: statusNotifyier)
            subsonicServerApi.requestPodcasts(parserDelegate: podcastParser)
            syncLibrary.saveContext()
        }

        syncWave.syncState = .Done
        syncLibrary.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    func sync(artist: Artist, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let artistParser = SsArtistParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestArtist(parserDelegate: artistParser, id: artist.id)
        for album in artist.albums {
            let songParser = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestAlbum(parserDelegate: songParser, id: album.id)
        }
        library.saveContext()
    }
    
    func sync(album: Album, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let songParser = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestAlbum(parserDelegate: songParser, id: album.id)
        library.saveContext()
    }
    
    func syncLatestLibraryElements(library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let oldRecentSongs = Set(library.getRecentSongs())
        
        os_log("Sync newest albums", log: log, type: .info)
        let albumDelegate = SsAlbumParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestLatestAlbums(parserDelegate: albumDelegate)
        library.saveContext()
        os_log("Sync songs of newest albums", log: log, type: .info)
        
        var recentlyAddedSongs: Set<Song> = Set()
        for album in albumDelegate.parsedAlbums {
            let songParser = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
            subsonicServerApi.requestAlbum(parserDelegate: songParser, id: album.id)
            recentlyAddedSongs = recentlyAddedSongs.union(Set(songParser.parsedSongs))
        }
        os_log("%i newest Albums synced", log: log, type: .info, albumDelegate.parsedAlbums.count)
        let notRecentSongsAnymore = oldRecentSongs.subtracting(recentlyAddedSongs)
        notRecentSongsAnymore.forEach { $0.isRecentlyAdded = false }
        recentlyAddedSongs.forEach { $0.isRecentlyAdded = true }
        library.saveContext()
    }
    
    func syncMusicFolders(library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let musicFolderParser = SsMusicFolderParserDelegate(library: library, syncWave: syncWave)
        subsonicServerApi.requestMusicFolders(parserDelegate: musicFolderParser)
        library.saveContext()
    }
    
    func syncIndexes(musicFolder: MusicFolder, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let musicDirectoryParser = SsDirectoryParserDelegate(musicFolder: musicFolder, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestIndexes(parserDelegate: musicDirectoryParser, musicFolderId: musicFolder.id)
        library.saveContext()
    }
    
    func sync(directory: Directory, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let musicDirectoryParser = SsDirectoryParserDelegate(directory: directory, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestMusicDirectory(parserDelegate: musicDirectoryParser, id: directory.id)
        library.saveContext()
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let songParser = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestRandomSongs(parserDelegate: songParser, count: count)
        playlist.append(playables: songParser.parsedSongs)
        library.saveContext()
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) {
        let songParser = SsXmlParser()
        subsonicServerApi.requestPodcastEpisodeDelete(parserDelegate: songParser, id: podcastEpisode.id)
    }
    
    func syncDownPlaylistsWithoutSongs(library: LibraryStorage) {
        let playlistParser = SsPlaylistParserDelegate(library: library)
        subsonicServerApi.requestPlaylists(parserDelegate: playlistParser)
        library.saveContext()
    }
    
    func syncDown(playlist: Playlist, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { return }
        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        let parser = SsPlaylistSongsParserDelegate(playlist: playlist, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        library.saveContext()
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        if playlist.id == "" {
            createPlaylistRemote(playlist: playlist, library: library, syncWave: syncWave)
        }
        guard playlist.id != "" else {
            os_log("Playlist id could not be obtained", log: log, type: .info)
            return
        }
        
        let songIdsToAdd = songs.compactMap{ $0.id }
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: [], songIdsToAdd: songIdsToAdd)
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, library: LibraryStorage) {
        os_log("Upload SongDelete on playlist \"%s\"", log: log, type: .info, playlist.name)
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: [index], songIdsToAdd: [])
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist, library: LibraryStorage) {
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        let songIndicesToRemove = Array(0...playlist.songCount-1)
        let songIdsToAdd = playlist.playables.compactMap{ $0.id }
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistUpdate(parserDelegate: updateResponseParser, playlist: playlist, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)
    }
    
    func syncUpload(playlistToDelete playlist: Playlist) {
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, playlist.name)
        let updateResponseParser = SsPingParserDelegate()
        subsonicServerApi.requestPlaylistDelete(parserDelegate: updateResponseParser, playlist: playlist)
    }
    
    func syncDownPodcastsWithoutEpisodes(library: LibraryStorage) {
        guard subsonicServerApi.isPodcastSupported, let syncWave = library.getLatestSyncWave() else { return }
        let podcastParser = SsPodcastParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestPodcasts(parserDelegate: podcastParser)
        library.saveContext()
    }
    
    func sync(podcast: Podcast, library: LibraryStorage) {
        guard subsonicServerApi.isPodcastSupported, let syncWave = library.getLatestSyncWave() else { return }
        let podcastEpisodeParser = SsPodcastEpisodeParserDelegate(podcast: podcast, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestPodcastEpisodes(parserDelegate: podcastEpisodeParser, id: podcast.id)
        library.saveContext()
    }
    
    func searchArtists(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SsArtistParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestSearchArtists(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }
    
    func searchAlbums(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SsAlbumParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestSearchAlbums(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }
    
    func searchSongs(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SsSongParserDelegate(library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestSearchSongs(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }
    
    private func createPlaylistRemote(playlist: Playlist, library: LibraryStorage, syncWave: SyncWave) {
        os_log("Create playlist on server", log: log, type: .info)
        let playlistParser = SsPlaylistSongsParserDelegate(playlist: playlist, library: library, syncWave: syncWave, subsonicUrlCreator: subsonicServerApi)
        subsonicServerApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        // Old api version -> need to match the created playlist via name
        if playlist.id == "" {
            updatePlaylistIdViaItsName(playlist: playlist, library: library)
        }
    }

    private func updatePlaylistIdViaItsName(playlist: Playlist, library: LibraryStorage) {
        syncDownPlaylistsWithoutSongs(library: library)
        let playlists = library.getPlaylists()
        let nameMatchingPlaylists = playlists.filter{ filterPlaylist in
            if filterPlaylist.name == playlist.name, filterPlaylist.id != "" {
                return true
            }
            return false
        }
        guard !nameMatchingPlaylists.isEmpty, let firstMatch = nameMatchingPlaylists.first else { return }
        let matchedId = firstMatch.id
        library.deletePlaylist(firstMatch)
        playlist.id = matchedId
    }
    
}
