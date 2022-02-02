import Foundation
import CoreData
import os.log

protocol PlayableFileCachable {
    func getFile(forPlayable playable: AbstractPlayable) -> PlayableFile?
}

enum PlaylistSearchCategory: Int {
    case all = 0
    case cached = 1
    case userOnly = 2
    case smartOnly = 3

    static let defaultValue: PlaylistSearchCategory = .all
}

class LibraryStorage: PlayableFileCachable {
    
    static let entitiesToDelete = [Genre.typeName, Artist.typeName, Album.typeName, Song.typeName, PlayableFile.typeName, Artwork.typeName, EmbeddedArtwork.typeName, SyncWave.typeName, Playlist.typeName, PlaylistItem.typeName, PlayerData.entityName, LogEntry.typeName, MusicFolder.typeName, Directory.typeName, Podcast.typeName, PodcastEpisode.typeName, Download.typeName]

    private let log = OSLog(subsystem: AppDelegate.name, category: "LibraryStorage")
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func getInfo() -> LibraryInfo {
        var libraryInfo = LibraryInfo()
        libraryInfo.artistCount = artistCount
        libraryInfo.albumCount = albumCount
        libraryInfo.songCount = songCount
        libraryInfo.cachedSongCount = cachedSongCount
        libraryInfo.playlistCount = playlistCount
        libraryInfo.cachedSongSize = cachedPlayableSizeInByte.asByteString
        libraryInfo.genreCount = genreCount
        libraryInfo.syncWaveCount = syncWaveCount
        libraryInfo.artworkCount = artworkCount
        libraryInfo.musicFolderCount = musicFolderCount
        libraryInfo.directoryCount = directoryCount
        libraryInfo.podcastCount = podcastCount
        libraryInfo.podcastEpisodeCount = podcastEpisodeCount
        return libraryInfo
    }
    
    var genreCount: Int {
        return (try? context.count(for: GenreMO.fetchRequest())) ?? 0
    }
    
    var artistCount: Int {
        return (try? context.count(for: ArtistMO.fetchRequest())) ?? 0
    }
    
    var albumCount: Int {
        return (try? context.count(for: AlbumMO.fetchRequest())) ?? 0
    }
    
    var songCount: Int {
        return (try? context.count(for: SongMO.fetchRequest())) ?? 0
    }
    
    var syncWaveCount: Int {
        return (try? context.count(for: SyncWaveMO.fetchRequest())) ?? 0
    }
    
    var artworkCount: Int {
        return (try? context.count(for: ArtworkMO.fetchRequest())) ?? 0
    }
    
    var musicFolderCount: Int {
        return (try? context.count(for: MusicFolderMO.fetchRequest())) ?? 0
    }
    
    var directoryCount: Int {
        return (try? context.count(for: DirectoryMO.fetchRequest())) ?? 0
    }
    
    var cachedSongCount: Int {
        let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    var playlistCount: Int {
        let request: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        request.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        return (try? context.count(for: request)) ?? 0
    }
    
    var podcastCount: Int {
        return (try? context.count(for: PodcastMO.fetchRequest())) ?? 0
    }
    
    var podcastEpisodeCount: Int {
        return (try? context.count(for: PodcastEpisodeMO.fetchRequest())) ?? 0
    }
    
    var cachedPodcastEpisodeCount: Int {
        let request: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.file))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    var cachedPlayableSizeInByte: Int64 {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: PlayableFile.typeName)
        fetchRequest.propertiesToFetch = [#keyPath(PlayableFileMO.data)]
        fetchRequest.resultType = .dictionaryResultType
        let foundPlayableFiles = (try? context.fetch(fetchRequest)) ?? [NSDictionary]()
        let files = foundPlayableFiles.compactMap{ $0[#keyPath(PlayableFileMO.data)] as? NSData }
        let cachedPlayableSizeInByte: Int64 = files.reduce(0, { $0 + $1.sizeInByte})
        return cachedPlayableSizeInByte
    }
    
    func createGenre() -> Genre {
        let genreMO = GenreMO(context: context)
        return Genre(managedObject: genreMO)
    }
    
    func createArtist() -> Artist {
        let artistMO = ArtistMO(context: context)
        return Artist(managedObject: artistMO)
    }
    
    func createAlbum() -> Album {
        let albumMO = AlbumMO(context: context)
        return Album(managedObject: albumMO)
    }
    
    func deleteAlbum(album: Album) {
        context.delete(album.managedObject)
    }
    
    func createPodcast() -> Podcast {
        let podcastMO = PodcastMO(context: context)
        return Podcast(managedObject: podcastMO)
    }
    
    func deletePodcast(_ podcast: Podcast) {
        context.delete(podcast.managedObject)
    }
    
    func createPodcastEpisode() -> PodcastEpisode {
        let podcastEpisodeMO = PodcastEpisodeMO(context: context)
        return PodcastEpisode(managedObject: podcastEpisodeMO)
    }
    
    func createSong() -> Song {
        let songMO = SongMO(context: context)
        return Song(managedObject: songMO)
    }
    
    func createPlayableFile() -> PlayableFile {
        let playableFileMO = PlayableFileMO(context: context)
        return PlayableFile(managedObject: playableFileMO)
    }
    
    func createMusicFolder() -> MusicFolder {
        let musicFolderMO = MusicFolderMO(context: context)
        return MusicFolder(managedObject: musicFolderMO)
    }
    
    func deleteMusicFolder(musicFolder: MusicFolder) {
        context.delete(musicFolder.managedObject)
    }
    
    func createDirectory() -> Directory {
        let directoryMO = DirectoryMO(context: context)
        return Directory(managedObject: directoryMO)
    }
    
    func deleteDirectory(directory: Directory) {
        context.delete(directory.managedObject)
    }
    
    func createLogEntry() -> LogEntry {
        let logEntryMO = LogEntryMO(context: context)
        logEntryMO.creationDate = Date()
        return LogEntry(managedObject: logEntryMO)
    }
    
    private func createUserStatistics(appVersion: String) -> UserStatistics {
        let userStatistics = UserStatisticsMO(context: context)
        userStatistics.creationDate = Date()
        userStatistics.appVersion = appVersion
        return UserStatistics(managedObject: userStatistics, library: self)
    }
    
    func deletePlayableFile(playableFile: PlayableFile) {
        context.delete(playableFile.managedObject)
    }

    func deleteCache(ofPlayable playable: AbstractPlayable) {
        if let playableFile = getFile(forPlayable: playable) {
            deletePlayableFile(playableFile: playableFile)
            playable.playableManagedObject.file = nil
        }
    }
    
    func deleteCache(of playableContainer: PlayableContainable) {
        for playable in playableContainer.playables {
            deleteCache(ofPlayable: playable)
        }
    }

    func deleteCompleteSongCache() {
        clearStorage(ofType: PlayableFile.typeName)
    }
    
    func createEmbeddedArtwork() -> EmbeddedArtwork {
        return EmbeddedArtwork(managedObject: EmbeddedArtworkMO(context: context))
    }
    
    func deleteEmbeddedArtworks() {
        let fetchRequest = EmbeddedArtworkMO.fetchRequest()
        guard let artworks = try? context.fetch(fetchRequest) else { return }
        for artwork in artworks {
            context.delete(artwork)
        }
    }

    func createArtwork() -> Artwork {
        return Artwork(managedObject: ArtworkMO(context: context))
    }
    
    func deleteArtwork(artwork: Artwork) {
        context.delete(artwork.managedObject)
    }
 
    func createPlaylist() -> Playlist {
        return Playlist(library: self, managedObject: PlaylistMO(context: context))
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist.managedObject)
    }
    
    func createPlaylistItem() -> PlaylistItem {
        let itemMO = PlaylistItemMO(context: context)
        return PlaylistItem(library: self, managedObject: itemMO)
    }
    
    func deletePlaylistItem(item: PlaylistItem) {
        context.delete(item.managedObject)
    }
    
    func deleteSyncWave(item: SyncWave) {
        context.delete(item.managedObject)
    }

    func createSyncWave() -> SyncWave {
        let syncWaveCount = Int16(getSyncWaves().count)
        let syncWaveMO = SyncWaveMO(context: context)
        syncWaveMO.id = syncWaveCount
        return SyncWave(managedObject: syncWaveMO)
    }
    
    func createDownload() -> Download {
        return Download(managedObject: DownloadMO(context: context))
    }
    
    func getDownload(id: String) -> Download? {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DownloadMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let downloads = try? context.fetch(fetchRequest)
        return downloads?.lazy.compactMap{ Download(managedObject: $0) }.first
    }
    
    func getDownload(url: String) -> Download? {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DownloadMO.urlString), NSString(string: url))
        fetchRequest.fetchLimit = 1
        let downloads = try? context.fetch(fetchRequest)
        return downloads?.lazy.compactMap{ Download(managedObject: $0) }.first
    }
    
    func deleteDownload(_ download: Download) {
        context.delete(download.managedObject)
    }
    
    func getFetchPredicate(forSyncWave syncWave: SyncWave) -> NSPredicate {
        return NSPredicate(format: "(syncInfo == %@)", syncWave.managedObject.objectID)
    }
    
    func getFetchPredicate(forGenre genre: Genre) -> NSPredicate {
        return NSPredicate(format: "genre == %@", genre.managedObject.objectID)
    }
    
    func getFetchPredicate(forArtist artist: Artist) -> NSPredicate {
        return NSPredicate(format: "artist == %@", artist.managedObject.objectID)
    }
    
    func getFetchPredicate(forAlbum album: Album) -> NSPredicate {
        return NSPredicate(format: "album == %@", album.managedObject.objectID)
    }
    
    func getFetchPredicate(forPlaylist playlist: Playlist) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(PlaylistItemMO.playlist), playlist.managedObject.objectID)
    }
    
    func getFetchPredicateForAvailablePodcasts() -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            getFetchPredicate(onlyCachedPodcasts: true),
            getFetchPredicateForRemoteAvailablePodcasts()
        ])
    }
    
    func getFetchPredicateForRemoteAvailablePodcasts() -> NSPredicate {
        return NSPredicate(format: "%K != %i", #keyPath(PodcastMO.status), PodcastRemoteStatus.deleted.rawValue)
    }
    
    func getFetchPredicateForUserAvailableEpisodes(forPodcast podcast: Podcast) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(PodcastEpisodeMO.podcast), podcast.managedObject.objectID),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                getFetchPredicate(onlyCachedPodcastEpisodes: true),
                NSPredicate(format: "%K != %i", #keyPath(PodcastEpisodeMO.status), PodcastEpisodeRemoteStatus.deleted.rawValue)
            ])
        ])
    }
    
    func getFetchPredicate(forMusicFolder musicFolder: MusicFolder) -> NSPredicate {
        return NSPredicate(format: "musicFolder == %@", musicFolder.managedObject.objectID)
    }
    
    func getSongFetchPredicate(forDirectory directory: Directory) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(SongMO.directory), directory.managedObject.objectID)
    }
    
    func getDirectoryFetchPredicate(forDirectory directory: Directory) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(DirectoryMO.parent), directory.managedObject.objectID)
    }
    
    func getFetchPredicate(onlyCachedArtists: Bool) -> NSPredicate {
        if onlyCachedArtists {
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedAlbums: Bool) -> NSPredicate {
        if onlyCachedAlbums {
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedPlaylistItems: Bool) -> NSPredicate {
        if onlyCachedPlaylistItems {
            return NSPredicate(format: "%K != nil", #keyPath(PlaylistItemMO.playable.file))
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedSongs: Bool) -> NSPredicate {
        if onlyCachedSongs {
            return NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedPodcasts: Bool) -> NSPredicate {
        if onlyCachedPodcasts {
            return NSPredicate(format: "SUBQUERY(episodes, $episode, $episode.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedPodcastEpisodes: Bool) -> NSPredicate {
        if onlyCachedPodcastEpisodes {
            return NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.file))
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreArtists: Bool) -> NSPredicate {
        if onlyCachedGenreArtists {
            return NSPredicate(format: "SUBQUERY(artists, $artist, ANY $artist.songs.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreAlbums: Bool) -> NSPredicate {
        if onlyCachedGenreAlbums {
            return NSPredicate(format: "SUBQUERY(albums, $album, ANY $album.songs.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreSongs: Bool) -> NSPredicate {
        if onlyCachedGenreSongs {
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.file != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(songsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch songsDisplayFilter {
        case .recentlyAdded:
            return NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isRecentlyAdded))
        case .all:
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(albumsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch albumsDisplayFilter {
        case .recentlyAdded:
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.isRecentlyAdded == TRUE) .@count > 0")
        case .all:
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(forPlaylistSearchCategory playlistSearchCategory: PlaylistSearchCategory) -> NSPredicate {
        switch playlistSearchCategory {
        case .all:
            return NSPredicate.alwaysTrue
        case .cached:
            return NSPredicate(format: "SUBQUERY(items, $item, $item.playable.file != nil) .@count > 0")
        case .userOnly:
            return NSPredicate(format: "NOT (%K BEGINSWITH %@)", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        case .smartOnly:
            return NSPredicate(format: "%K BEGINSWITH %@", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        }
    }

    func getArtists() -> [Artist] {
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        let foundArtists = try? context.fetch(fetchRequest)
        let artists = foundArtists?.compactMap{ Artist(managedObject: $0) }
        return artists ?? [Artist]()
    }
    
    func getAlbums() -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    func getAlbums(whichContainsSongsWithArtist artist: Artist) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            self.getFetchPredicate(forArtist: artist),
            AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist)
        ])
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    func getPodcasts() -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }

    func getRemoteAvailablePodcasts() -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        fetchRequest.predicate = getFetchPredicateForRemoteAvailablePodcasts()
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }

    func getSongs() -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    func getRecentSongs() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isRecentlyAdded))
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    func getPlaylists() -> [Playlist] {
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        let foundPlaylists = try? context.fetch(fetchRequest)
        let playlists = foundPlaylists?.compactMap{ Playlist(library: self, managedObject: $0) }
        return playlists ?? [Playlist]()
    }
    
    func getLogEntries() -> [LogEntry] {
        let fetchRequest: NSFetchRequest<LogEntryMO> = LogEntryMO.creationDateSortedFetchRequest
        let foundEntries = try? context.fetch(fetchRequest)
        let entries = foundEntries?.compactMap{ LogEntry(managedObject: $0) }
        return entries ?? [LogEntry]()
    }
    
    func getPlayerData() -> PlayerData {
        let fetchRequest: NSFetchRequest<PlayerMO> = PlayerMO.fetchRequest()
        var playerData: PlayerData
        var playerMO: PlayerMO

        if let fetchResults: [PlayerMO] = try? context.fetch(fetchRequest) {
            if fetchResults.count == 1 {
                playerMO = fetchResults[0]
            } else if (fetchResults.count == 0) {
                playerMO = PlayerMO(context: context)
                saveContext()
            } else {
                clearStorage(ofType: PlayerData.entityName)
                playerMO = PlayerMO(context: context)
                saveContext()
            }
        } else {
            playerMO = PlayerMO(context: context)
            saveContext()
        }
        
        if playerMO.userQueuePlaylist == nil {
            playerMO.userQueuePlaylist = PlaylistMO(context: context)
            saveContext()
        }
        if playerMO.contextPlaylist == nil {
            playerMO.contextPlaylist = PlaylistMO(context: context)
            saveContext()
        }
        if playerMO.shuffledContextPlaylist == nil {
            playerMO.shuffledContextPlaylist = PlaylistMO(context: context)
            saveContext()
        }
        
        let userQueuePlaylist = Playlist(library: self, managedObject: playerMO.userQueuePlaylist!)
        let contextPlaylist = Playlist(library: self, managedObject: playerMO.contextPlaylist!)
        let shuffledContextPlaylist = Playlist(library: self, managedObject: playerMO.shuffledContextPlaylist!)
        
        if shuffledContextPlaylist.items.count != contextPlaylist.items.count {
            shuffledContextPlaylist.removeAllItems()
            shuffledContextPlaylist.append(playables: contextPlaylist.playables)
            shuffledContextPlaylist.shuffle()
        }
        
        playerData = PlayerData(library: self, managedObject: playerMO, userQueue: userQueuePlaylist, contextQueue: contextPlaylist, shuffledContextQueue: shuffledContextPlaylist)
        
        return playerData
    }

    func getGenre(id: String) -> Genre? {
        let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let genres = try? context.fetch(fetchRequest)
        return genres?.lazy.compactMap{ Genre(managedObject: $0) }.first
    }
    
    func getGenre(name: String) -> Genre? {
        let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.name), NSString(string: name))
        fetchRequest.fetchLimit = 1
        let genres = try? context.fetch(fetchRequest)
        return genres?.lazy.compactMap{ Genre(managedObject: $0) }.first
    }
    
    func getArtist(id: String) -> Artist? {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let artists = try? context.fetch(fetchRequest)
        return artists?.lazy.compactMap{ Artist(managedObject: $0) }.first
    }
    
    func getAlbum(id: String) -> Album? {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(AlbumMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let albums = try? context.fetch(fetchRequest)
        return albums?.lazy.compactMap{ Album(managedObject: $0) }.first
    }
    
    func getPodcast(id: String) -> Podcast? {
        let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let albums = try? context.fetch(fetchRequest)
        return albums?.lazy.compactMap{ Podcast(managedObject: $0) }.first
    }
    
    func getPodcastEpisode(id: String) -> PodcastEpisode? {
        let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastEpisodeMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let songs = try? context.fetch(fetchRequest)
        return songs?.lazy.compactMap{ PodcastEpisode(managedObject: $0) }.first
    }
    
    func getSong(id: String) -> Song? {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(SongMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let songs = try? context.fetch(fetchRequest)
        return songs?.lazy.compactMap{ Song(managedObject: $0) }.first
    }
    
    func getFile(forPlayable playable: AbstractPlayable) -> PlayableFile? {
        guard playable.isCached else { return nil }
        let fetchRequest: NSFetchRequest<PlayableFileMO> = PlayableFileMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PlayableFileMO.info.id), NSString(string: playable.id))
        fetchRequest.fetchLimit = 1
        let playableFiles = try? context.fetch(fetchRequest)
        return playableFiles?.lazy.compactMap{ PlayableFile(managedObject: $0) }.first
    }

    func getPlaylist(id: String) -> Playlist? {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PlaylistMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let playlists = try? context.fetch(fetchRequest)
        return playlists?.lazy.compactMap{ Playlist(library: self, managedObject: $0) }.first
    }
    
    func getPlaylist(viaPlaylistFromOtherContext: Playlist) -> Playlist? {
        guard let foundManagedPlaylist = context.object(with: viaPlaylistFromOtherContext.managedObject.objectID) as? PlaylistMO else { return nil }
        return Playlist(library: self, managedObject: foundManagedPlaylist)
    }
    
    func getArtworks() -> [Artwork] {
        let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        let foundMusicFolders = try? context.fetch(fetchRequest)
        let artworks = foundMusicFolders?.compactMap{ Artwork(managedObject: $0) }
        return artworks ?? [Artwork]()
    }
    
    func getArtwork(remoteInfo: ArtworkRemoteInfo) -> Artwork? {
        let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.id), NSString(string: remoteInfo.id)),
            NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.type), NSString(string: remoteInfo.type))
        ])
        fetchRequest.fetchLimit = 1
        let artworks = try? context.fetch(fetchRequest)
        return artworks?.lazy.compactMap{ Artwork(managedObject: $0) }.first
    }
    
    func getArtworksThatAreNotChecked(fetchCount: Int = 10) -> [Artwork] {
        let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue)))
        fetchRequest.fetchLimit = fetchCount
        let foundArtworks = try? context.fetch(fetchRequest)
        let artworks = foundArtworks?.compactMap{ Artwork(managedObject: $0) }
        return artworks ?? [Artwork]()
    }

    func getSyncWaves() -> [SyncWave] {
        let fetchRequest: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        let foundSyncWaves = try? context.fetch(fetchRequest)
        let syncWaves = foundSyncWaves?.compactMap{ SyncWave(managedObject: $0) }
        return syncWaves ?? [SyncWave]()
    }

    func getLatestSyncWave() -> SyncWave? {
        let fetchRequest: NSFetchRequest<SyncWaveMO> = SyncWaveMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == max(%K)", #keyPath(SyncWaveMO.id), #keyPath(SyncWaveMO.id))
        fetchRequest.fetchLimit = 1
        let syncWaves = try? context.fetch(fetchRequest)
        return syncWaves?.lazy.compactMap{ SyncWave(managedObject: $0) }.first
    }
    
    func getUserStatistics(appVersion: String) -> UserStatistics {
        let fetchRequest: NSFetchRequest<UserStatisticsMO> = UserStatisticsMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(UserStatisticsMO.appVersion), appVersion)
        fetchRequest.fetchLimit = 1
        if let foundUserStatistics = try? context.fetch(fetchRequest).first {
            return UserStatistics(managedObject: foundUserStatistics, library: self)
        } else {
            os_log("New UserStatistics for app version %s created", log: log, type: .info, appVersion)
            let createdUserStatistics = createUserStatistics(appVersion: appVersion)
            saveContext()
            return createdUserStatistics
        }
    }
    
    func getAllUserStatistics() -> [UserStatistics] {
        let fetchRequest: NSFetchRequest<UserStatisticsMO> = UserStatisticsMO.fetchRequest()
        let foundUserStatistics = try? context.fetch(fetchRequest)
        let userStatistics = foundUserStatistics?.compactMap{ UserStatistics(managedObject: $0, library: self) }
        return userStatistics ?? [UserStatistics]()
    }
    
    func getMusicFolders() -> [MusicFolder] {
        let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
        let foundMusicFolders = try? context.fetch(fetchRequest)
        let musicFolders = foundMusicFolders?.compactMap{ MusicFolder(managedObject: $0) }
        return musicFolders ?? [MusicFolder]()
    }
    
    func getMusicFolder(id: String) -> MusicFolder? {
        let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(MusicFolderMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let musicFolders = try? context.fetch(fetchRequest)
        return musicFolders?.lazy.compactMap{ MusicFolder(managedObject: $0) }.first
    }
    
    func getDirectory(id: String) -> Directory? {
        let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DirectoryMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let directories = try? context.fetch(fetchRequest)
        return directories?.lazy.compactMap{ Directory(managedObject: $0) }.first
    }
    
    func cleanStorage() {
        for entityToDelete in LibraryStorage.entitiesToDelete {
            clearStorage(ofType: entityToDelete)
        }
        saveContext()
    }
    
    private func clearStorage(ofType entityToDelete: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityToDelete)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch let error as NSError {
            os_log("Fetch failed: %s", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func saveContext () {
        if context.hasChanges {
            do {
                context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.localizedDescription)")
            }
        }
    }
    
}
