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
    var podcastCount: Int {
        return ampacheXmlServerApi.podcastCount
    }
    
    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    func sync(currentContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer, statusNotifyier: SyncCallbacks? = nil) {
        guard let libMetaData = ampacheXmlServerApi.requesetLibraryMetaData() else { return }
        
        let taskGroup = ConcurrentTaskGroup(taskSlotsCount: 5)
        let syncLibrary = LibraryStorage(context: currentContext)

        let syncWave = syncLibrary.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: libMetaData.libraryChangeDates)
        syncLibrary.saveContext()

        statusNotifyier?.notifySyncStarted(ofType: .genre)
        let genreParser = GenreParserDelegate(library: syncLibrary, syncWave: syncWave, parseNotifier: statusNotifyier)
        self.ampacheXmlServerApi.requestGenres(parserDelegate: genreParser)
        syncLibrary.saveContext()

        statusNotifyier?.notifySyncStarted(ofType: .artist)
        let pollCountArtist = (ampacheXmlServerApi.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCountArtist {
            taskGroup.waitForSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let batchLibrary = LibraryStorage(context: context)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let artistParser = ArtistParserDelegate(library: batchLibrary, syncWave: syncWaveContext, parseNotifier: statusNotifyier)
                self.ampacheXmlServerApi.requestArtists(parserDelegate: artistParser, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                batchLibrary.saveContext()
                taskGroup.taskFinished()
            }
        }
        taskGroup.waitTillAllTasksFinished()

        statusNotifyier?.notifySyncStarted(ofType: .album)
        let pollCountAlbum = (ampacheXmlServerApi.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce)
        for i in 0...pollCountAlbum {
            taskGroup.waitForSlot()
            persistentContainer.performBackgroundTask() { (context) in
                let batchLibrary = LibraryStorage(context: context)
                let syncWaveMO = try! context.existingObject(with: syncWave.managedObject.objectID) as! SyncWaveMO
                let syncWaveContext = SyncWave(managedObject: syncWaveMO)
                let albumDelegate = AlbumParserDelegate(library: batchLibrary, syncWave: syncWaveContext, parseNotifier: statusNotifyier)
                self.ampacheXmlServerApi.requestAlbums(parserDelegate: albumDelegate, startIndex: i*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                batchLibrary.saveContext()
                taskGroup.taskFinished()
            }
        }
        taskGroup.waitTillAllTasksFinished()
        
        statusNotifyier?.notifySyncStarted(ofType: .playlist)
        let playlistParser = PlaylistParserDelegate(library: syncLibrary, parseNotifier: statusNotifyier)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
        syncLibrary.saveContext()
        
        if ampacheXmlServerApi.isPodcastSupported {
            statusNotifyier?.notifySyncStarted(ofType: .podcast)
            let podcastParser = PodcastParserDelegate(library: syncLibrary, syncWave: syncWave, parseNotifier: statusNotifyier)
            ampacheXmlServerApi.requestPodcasts(parserDelegate: podcastParser)
            syncLibrary.saveContext()
        }
        
        syncWave.syncState = .Done
        syncLibrary.saveContext()
        statusNotifyier?.notifySyncFinished()
    }
    
    func sync(genre: Genre, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        for album in genre.albums {
            let albumParser = AlbumParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
            self.ampacheXmlServerApi.requestAlbumInfo(of: album, parserDelegate: albumParser)
            if let error = albumParser.error?.asAmpacheError, !error.isRemoteAvailable {
                os_log("Album <%s> is remote deleted", log: log, type: .info, album.name)
                album.remoteStatus = .deleted
            } else {
                let songParser = SongParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
                self.ampacheXmlServerApi.requestAlbumSongs(of: album, parserDelegate: songParser)
            }
        }
        library.saveContext()
    }
    
    func sync(artist: Artist, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let artistParser = ArtistParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestArtistInfo(of: artist, parserDelegate: artistParser)
        if let error = artistParser.error?.asAmpacheError, !error.isRemoteAvailable {
            os_log("Artist <%s> is remote deleted", log: log, type: .info, artist.name)
            artist.remoteStatus = .deleted
        } else {
            let albumParser = AlbumParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
            self.ampacheXmlServerApi.requestArtistAlbums(of: artist, parserDelegate: albumParser)
            let songParser = SongParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
            self.ampacheXmlServerApi.requestArtistSongs(of: artist, parserDelegate: songParser)
        }
        library.saveContext()
    }
    
    func sync(album: Album, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let albumParser = AlbumParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestAlbumInfo(of: album, parserDelegate: albumParser)
        if let error = albumParser.error?.asAmpacheError, !error.isRemoteAvailable {
            os_log("Album <%s> is remote deleted", log: log, type: .info, album.name)
            album.remoteStatus = .deleted
        } else {
            let songParser = SongParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
            self.ampacheXmlServerApi.requestAlbumSongs(of: album, parserDelegate: songParser)
        }
        library.saveContext()
    }
    
    func sync(song: Song, library: LibraryStorage) {
        guard let syncWave = song.syncInfo ?? library.getLatestSyncWave() else { return }
        let songParser = SongParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
        self.ampacheXmlServerApi.requestSongInfo(of: song, parserDelegate: songParser)
        library.saveContext()
    }
    
    func syncMusicFolders(library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let catalogParser = CatalogParserDelegate(library: library, syncWave: syncWave)
        self.ampacheXmlServerApi.requestCatalogs(parserDelegate: catalogParser)
        library.saveContext()
    }
    
    func syncIndexes(musicFolder: MusicFolder, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let artistParser = ArtistParserDelegate(library: library, syncWave: syncWave)
        self.ampacheXmlServerApi.requestArtistWithinCatalog(of: musicFolder, parserDelegate: artistParser)
        
        let directoriesBeforeFetch = Set(musicFolder.directories)
        var directoriesAfterFetch: Set<Directory> = Set()
        for artist in artistParser.artistsParsed {
            let artistDirId = "artist-\(artist.id)"
            var curDir: Directory!
            if let foundDir = library.getDirectory(id: artistDirId) {
                curDir = foundDir
            } else {
                curDir = library.createDirectory()
                curDir.id = artistDirId
            }
            curDir.name = artist.name
            musicFolder.managedObject.addToDirectories(curDir.managedObject)
            directoriesAfterFetch.insert(curDir)
        }
        
        let removedDirectories = directoriesBeforeFetch.subtracting(directoriesAfterFetch)
        removedDirectories.forEach{ library.deleteDirectory(directory: $0) }
        
        library.saveContext()
    }
    
    func sync(directory: Directory, library: LibraryStorage) {
        if directory.id.starts(with: "album-") {
            let albumId = String(directory.id.dropFirst("album-".count))
            guard let album = library.getAlbum(id: albumId) else { return }
            let songsBeforeFetch = Set(directory.songs)
            sync(album: album, library: library)
            directory.songs.forEach { directory.managedObject.removeFromSongs($0.managedObject) }
            let songsToRemove = songsBeforeFetch.subtracting(Set(album.songs.compactMap{$0.asSong}))
            songsToRemove.lazy.compactMap{$0.asSong}.forEach{
                directory.managedObject.removeFromSongs($0.managedObject)
            }
            album.songs.compactMap{$0.asSong}.forEach{
                directory.managedObject.addToSongs($0.managedObject)
            }
            library.saveContext()
        } else if directory.id.starts(with: "artist-"){
            let artistId = String(directory.id.dropFirst("artist-".count))
            guard let artist = library.getArtist(id: artistId) else { return }
            let directoriesBeforeFetch = Set(directory.subdirectories)
            sync(artist: artist, library: library)

            var directoriesAfterFetch: Set<Directory> = Set()
            let artistAlbums = library.getAlbums(whichContainsSongsWithArtist: artist)
            for album in artistAlbums {
                let albumDirId = "album-\(album.id)"
                var albumDir: Directory!
                if let foundDir = library.getDirectory(id: albumDirId) {
                    albumDir = foundDir
                } else {
                    albumDir = library.createDirectory()
                    albumDir.id = albumDirId
                }
                albumDir.name = album.name
                albumDir.artwork = album.artwork
                directory.managedObject.addToSubdirectories(albumDir.managedObject)
                directoriesAfterFetch.insert(albumDir)
            }
            
            let directoriesToRemove = directoriesBeforeFetch.subtracting(directoriesAfterFetch)
            directoriesToRemove.forEach{
                directory.managedObject.removeFromSubdirectories($0.managedObject)
            }
            library.saveContext()
        }
    }
    
    func syncRecentSongs(library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let oldRecentSongs = Set(library.getRecentSongs())
        
        os_log("Sync recently added songs", log: log, type: .info)
        let songParser = SongParserDelegate(library: library, syncWave: syncWave)
        ampacheXmlServerApi.requestRecentSongs(parserDelegate: songParser, count: 50)
        library.saveContext()
        
        let notRecentSongsAnymore = oldRecentSongs.subtracting(songParser.parsedSongs)
        notRecentSongsAnymore.forEach { $0.isRecentlyAdded = false }
        songParser.parsedSongs.forEach { $0.isRecentlyAdded = true }
        library.saveContext()
    }
    
    func syncLatestLibraryElements(library: LibraryStorage) {
        syncRecentSongs(library: library)
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        let parser = SongParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
        ampacheXmlServerApi.requestRandomSongs(parserDelegate: parser, count: count)
        playlist.append(playables: parser.parsedSongs)
        library.saveContext()
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) {
        let parser = AmpacheXmlParser()
        ampacheXmlServerApi.requestPodcastEpisodeDelete(parserDelegate: parser, id: podcastEpisode.id)
    }

    func syncDownPlaylistsWithoutSongs(library: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(library: library, parseNotifier: nil)
        ampacheXmlServerApi.requestPlaylists(parserDelegate: playlistParser)
        library.saveContext()
    }
    
    func syncDown(playlist: Playlist, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave() else { return }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        guard playlist.id != "" else { return }
        validatePlaylistId(playlist: playlist, library: library)
        guard playlist.id != "" else { return }

        os_log("Sync songs of playlist \"%s\"", log: log, type: .info, playlist.name)
        let parser = PlaylistSongsParserDelegate(playlist: playlist, library: library, syncWave: syncWave)
        ampacheXmlServerApi.requestPlaylistSongs(parserDelegate: parser, id: playlist.id)
        playlist.ensureConsistentItemOrder()
        library.saveContext()
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], library: LibraryStorage) {
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        validatePlaylistId(playlist: playlist, library: library)
        for song in songs {
            ampacheXmlServerApi.requestPlaylistAddSong(playlist: playlist, song: song)
        }
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, library: LibraryStorage) {
        os_log("Upload SongDelete on playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistDeleteItem(playlist: playlist, index: index)
    }
    
    func syncUpload(playlistToUpdateName playlist: Playlist, library: LibraryStorage) {
        os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistEditOnlyName(playlist: playlist)
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist, library: LibraryStorage) {
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistEdit(playlist: playlist)
    }
    
    func syncUpload(playlistToDelete playlist: Playlist) {
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, playlist.name)
        ampacheXmlServerApi.requestPlaylistDelete(playlist: playlist)
    }
    
    private func validatePlaylistId(playlist: Playlist, library: LibraryStorage) {
        let playlistParser = PlaylistParserDelegate(library: library, parseNotifier: nil, playlistToValidate: playlist)
        ampacheXmlServerApi.requestPlaylist(parserDelegate: playlistParser, id: playlist.id)
        if playlist.id == "" {
            os_log("Create playlist on server", log: log, type: .info)
            let playlistParser = PlaylistParserDelegate(library: library, parseNotifier: nil, playlistToValidate: playlist)
            ampacheXmlServerApi.requestPlaylistCreate(parserDelegate: playlistParser, playlist: playlist)
        }
    }
    
    func syncDownPodcastsWithoutEpisodes(library: LibraryStorage) {
        guard ampacheXmlServerApi.isPodcastSupported, let syncWave = library.getLatestSyncWave() else { return }
        let oldPodcasts = Set(library.getRemoteAvailablePodcasts())
        
        let podcastParser = PodcastParserDelegate(library: library, syncWave: syncWave, parseNotifier: nil)
        ampacheXmlServerApi.requestPodcasts(parserDelegate: podcastParser)
        library.saveContext()
        
        let deletedPodcasts = oldPodcasts.subtracting(podcastParser.parsedPodcasts)
        deletedPodcasts.forEach { $0.remoteStatus = .deleted }
        library.saveContext()
    }
    
    func sync(podcast: Podcast, library: LibraryStorage) {
        guard ampacheXmlServerApi.isPodcastSupported, let syncWave = library.getLatestSyncWave() else { return }
        let oldEpisodes = Set(podcast.episodes)
        
        let podcastEpisodeParser = PodcastEpisodeParserDelegate(podcast: podcast, library: library, syncWave: syncWave)
        self.ampacheXmlServerApi.requestPodcastEpisodes(of: podcast, parserDelegate: podcastEpisodeParser)
        library.saveContext()

        let deletedEpisodes = oldEpisodes.subtracting(podcastEpisodeParser.parsedEpisodes)
        deletedEpisodes.forEach { $0.podcastStatus = .deleted }
        library.saveContext()
    }
    
    func scrobble(song: Song, date: Date?) {
        if let date = date {
            os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
        } else {
            os_log("Scrobble now: %s", log: log, type: .info, song.displayString)
        }
        let parser = AmpacheXmlParser()
        ampacheXmlServerApi.requestRecordPlay(parserDelegate: parser, song: song, date: date)
    }
    
    func setRating(song: Song, rating: Int) {
        guard rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
        ampacheXmlServerApi.requestRate(song: song, rating: rating)
    }
    
    func setRating(album: Album, rating: Int) {
        guard rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
        ampacheXmlServerApi.requestRate(album: album, rating: rating)
    }
    
    func setRating(artist: Artist, rating: Int) {
        guard rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
        ampacheXmlServerApi.requestRate(artist: artist, rating: rating)
    }
    
    func searchArtists(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        let parser = ArtistParserDelegate(library: library, syncWave: syncWave)
        ampacheXmlServerApi.requestSearchArtists(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }
    
    func searchAlbums(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        let parser = AlbumParserDelegate(library: library, syncWave: syncWave)
        ampacheXmlServerApi.requestSearchAlbums(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }
    
    func searchSongs(searchText: String, library: LibraryStorage) {
        guard let syncWave = library.getLatestSyncWave(), searchText.count > 0 else { return }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        let parser = SongParserDelegate(library: library, syncWave: syncWave)
        ampacheXmlServerApi.requestSearchSongs(parserDelegate: parser, searchText: searchText)
        library.saveContext()
    }

}
