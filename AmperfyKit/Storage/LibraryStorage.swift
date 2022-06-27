import Foundation
import CoreData
import os.log

protocol PlayableFileCachable {
    func getFile(forPlayable playable: AbstractPlayable) -> PlayableFile?
}

public enum PlaylistSearchCategory: Int {
    case all = 0
    case cached = 1
    case userOnly = 2
    case smartOnly = 3

    public static let defaultValue: PlaylistSearchCategory = .all
}

struct LibraryDuplicateInfo {
    let id: String
    let count: Int
}

public class LibraryStorage: PlayableFileCachable {
    
    static let entitiesToDelete = [Genre.typeName, Artist.typeName, Album.typeName, Song.typeName, PlayableFile.typeName, Artwork.typeName, EmbeddedArtwork.typeName, SyncWave.typeName, Playlist.typeName, PlaylistItem.typeName, PlayerData.entityName, LogEntry.typeName, MusicFolder.typeName, Directory.typeName, Podcast.typeName, PodcastEpisode.typeName, Download.typeName, ScrobbleEntry.typeName]
    static var carPlayMaxElements = 12

    private let log = OSLog(subsystem: "Amperfy", category: "LibraryStorage")
    private var context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func resolveGenresDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var genreDuplicates = getGenres(id: $0.id)
            if genreDuplicates.count > 1 {
                let leadGenre = genreDuplicates.removeFirst()
                os_log("Duplicated Genre (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadGenre.name)
                for genre in genreDuplicates {
                    genre.managedObject.passOwnership(to: leadGenre.managedObject)
                    context.delete(genre.managedObject)
                }
            }
        }
    }
    
    func resolveArtistsDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var artistDuplicates = getArtists(id: $0.id)
            let leadArtist = artistDuplicates.removeFirst()
            os_log("Duplicated Artist (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadArtist.name)
            for artist in artistDuplicates {
                artist.managedObject.passOwnership(to: leadArtist.managedObject)
                context.delete(artist.managedObject)
            }
        }
    }
    
    
    func resolveAlbumsDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var albumDuplicates = getAlbums(id: $0.id)
            let leadAlbum = albumDuplicates.removeFirst()
            os_log("Duplicated Album (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadAlbum.name)
            for album in albumDuplicates {
                album.managedObject.passOwnership(to: leadAlbum.managedObject)
                context.delete(album.managedObject)
            }
        }
    }
    
    func resolveSongsDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var songDuplicates = getSongs(id: $0.id)
            let leadSong = songDuplicates.removeFirst()
            os_log("Duplicated Song (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadSong.displayString)
            for song in songDuplicates {
                song.managedObject.passOwnership(to: leadSong.managedObject)
                deleteCache(ofPlayable: song)
                if let embeddedArtwork = song.managedObject.embeddedArtwork {
                    context.delete(embeddedArtwork)
                }
                if let download = song.managedObject.download {
                    context.delete(download)
                }
                context.delete(song.managedObject)
            }
        }
    }
    
    func resolvePodcastEpisodesDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var podcastEpisodesDuplicates = getPodcastEpisodes(id: $0.id)
            let leadPodcastEpisodes = podcastEpisodesDuplicates.removeFirst()
            os_log("Duplicated Podcast Episode (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadPodcastEpisodes.displayString)
            for podcastEpisode in podcastEpisodesDuplicates {
                podcastEpisode.managedObject.passOwnership(to: leadPodcastEpisodes.managedObject)
                deleteCache(ofPlayable: leadPodcastEpisodes)
                if let embeddedArtwork = podcastEpisode.managedObject.embeddedArtwork {
                    context.delete(embeddedArtwork)
                }
                if let download = podcastEpisode.managedObject.download {
                    context.delete(download)
                }
                context.delete(podcastEpisode.managedObject)
            }
        }
    }
    
    func resolvePodcastsDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var podcastDuplicates = getPodcasts(id: $0.id)
            let leadPodcast = podcastDuplicates.removeFirst()
            os_log("Duplicated Podcast (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadPodcast.name)
            for podcast in podcastDuplicates {
                podcast.managedObject.passOwnership(to: leadPodcast.managedObject)
                context.delete(podcast.managedObject)
            }
        }
    }
    
    func resolvePlaylistsDuplicates(duplicates: [LibraryDuplicateInfo]) {
        duplicates.forEach {
            var playlistDuplicates = getPlaylists(id: $0.id)
            let leadPlaylist = playlistDuplicates.removeFirst()
            os_log("Duplicated Playlist (count %i) (id: %s): %s", log: log, type: .info, $0.count, $0.id, leadPlaylist.name)
            for playlist in playlistDuplicates {
                playlist.managedObject.passOwnership(to: leadPlaylist.managedObject)
                deletePlaylist(playlist)
            }
        }
    }
    
    func findDuplicates(for entityName: String) -> [LibraryDuplicateInfo] {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: entityName)
        let idExpr = NSExpression(forKeyPath: "id")
        let countExpr = NSExpressionDescription()
        let countVariableExpr = NSExpression(forVariable: "count")

        countExpr.name = "count"
        countExpr.expression = NSExpression(forFunction: "count:", arguments: [ idExpr ])
        countExpr.expressionResultType = .integer64AttributeType

        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "id", ascending: true) ]
        fetchRequest.propertiesToGroupBy = [ #keyPath(AbstractLibraryEntityMO.id) ]
        fetchRequest.propertiesToFetch = [ #keyPath(AbstractLibraryEntityMO.id), countExpr ]
        fetchRequest.havingPredicate = NSPredicate(format: "%@ > 1", countVariableExpr)

        let results = (try? context.fetch(fetchRequest)) ?? [NSDictionary]()
        return results.compactMap{
            guard let id = $0["id"] as? String, let count = $0["count"] as? Int else { return nil }
            return LibraryDuplicateInfo(id: id, count: count)
        }
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
    
    public var genreCount: Int {
        return (try? context.count(for: GenreMO.fetchRequest())) ?? 0
    }
    
    public var artistCount: Int {
        return (try? context.count(for: ArtistMO.fetchRequest())) ?? 0
    }
    
    public var albumCount: Int {
        let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %i", #keyPath(AlbumMO.remoteStatus), RemoteStatus.available.rawValue)
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var albumWithSyncedSongsCount: Int {
        let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %i", #keyPath(AlbumMO.remoteStatus), RemoteStatus.available.rawValue),
            NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isSongsMetaDataSynced))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var albumWithoutSyncedSongsCount: Int {
        let request: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %i", #keyPath(AlbumMO.remoteStatus), RemoteStatus.available.rawValue),
            NSPredicate(format: "%K == FALSE", #keyPath(AlbumMO.isSongsMetaDataSynced))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var songCount: Int {
        return (try? context.count(for: SongMO.fetchRequest())) ?? 0
    }
    
    public var uploadableScrobbleEntryCount: Int {
        let fetchRequest = ScrobbleEntryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == FALSE", #keyPath(ScrobbleEntryMO.isUploaded))
        return (try? context.count(for: fetchRequest)) ?? 0
    }
    
    public var syncWaveCount: Int {
        return (try? context.count(for: SyncWaveMO.fetchRequest())) ?? 0
    }
    
    public var artworkCount: Int {
        return (try? context.count(for: ArtworkMO.fetchRequest())) ?? 0
    }

    public var artworkNotCheckedCount: Int {
        let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.imageData)),
            NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue))),
        ])
        return (try? context.count(for: request)) ?? 0
    }

    public var cachedArtworkCount: Int {
        let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.imageData))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var musicFolderCount: Int {
        return (try? context.count(for: MusicFolderMO.fetchRequest())) ?? 0
    }
    
    public var directoryCount: Int {
        return (try? context.count(for: DirectoryMO.fetchRequest())) ?? 0
    }
    
    public var cachedSongCount: Int {
        let request: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var playlistCount: Int {
        let request: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        request.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        return (try? context.count(for: request)) ?? 0
    }
    
    public var podcastCount: Int {
        return (try? context.count(for: PodcastMO.fetchRequest())) ?? 0
    }
    
    public var podcastEpisodeCount: Int {
        return (try? context.count(for: PodcastEpisodeMO.fetchRequest())) ?? 0
    }
    
    public var cachedPodcastEpisodeCount: Int {
        let request: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.file))
        ])
        return (try? context.count(for: request)) ?? 0
    }
    
    public var cachedPlayableSizeInByte: Int64 {
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
    
    func deleteArtist(artist: Artist) {
        context.delete(artist.managedObject)
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
    
    func createScrobbleEntry() -> ScrobbleEntry {
        let scrobbleEntryMO = ScrobbleEntryMO(context: context)
        return ScrobbleEntry(managedObject: scrobbleEntryMO)
    }
    
    func deleteScrobbleEntry(_ scrobbleEntry: ScrobbleEntry) {
        context.delete(scrobbleEntry.managedObject)
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
    
    public func deletePlayableFile(playableFile: PlayableFile) {
        context.delete(playableFile.managedObject)
    }

    public func deleteCache(ofPlayable playable: AbstractPlayable) {
        if let playableFile = getFile(forPlayable: playable) {
            deletePlayableFile(playableFile: playableFile)
            playable.playableManagedObject.file = nil
        }
    }
    
    public func deleteCache(of playables: [AbstractPlayable]) {
        for playable in playables {
            deleteCache(ofPlayable: playable)
        }
    }

    public func deleteCache(of playableContainer: PlayableContainable) {
        for playable in playableContainer.playables {
            deleteCache(ofPlayable: playable)
        }
    }

    public func deleteCompleteSongCache() {
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
 
    public func createPlaylist() -> Playlist {
        return Playlist(library: self, managedObject: PlaylistMO(context: context))
    }
    
    public func deletePlaylist(_ playlist: Playlist) {
        let playlistEntries = playlist.managedObject.items
        playlistEntries?.compactMap{ $0 as? PlaylistItemMO }.forEach{
            context.delete($0)
        }
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
    
    func getFetchPredicateForUserAvailableEpisodes() -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            getFetchPredicate(onlyCachedPodcastEpisodes: true),
            NSPredicate(format: "%K != %i", #keyPath(PodcastEpisodeMO.status), PodcastEpisodeRemoteStatus.deleted.rawValue)
        ])
    }
    
    func getFetchPredicateForUserAvailableEpisodes(forPodcast podcast: Podcast) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(PodcastEpisodeMO.podcast), podcast.managedObject.objectID),
            getFetchPredicateForUserAvailableEpisodes()
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
        case .all:
            return NSPredicate.alwaysTrue
        case .recentlyAdded:
            return NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isRecentlyAdded))
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isFavorite))
        }
    }
    
    func getFetchPredicate(albumsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch albumsDisplayFilter {
        case .all:
            return NSPredicate.alwaysTrue
        case .recentlyAdded:
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.isRecentlyAdded == TRUE) .@count > 0")
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isFavorite))
        }
    }

    func getFetchPredicate(artistsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch artistsDisplayFilter {
        case .all, .recentlyAdded:
            return NSPredicate.alwaysTrue
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(ArtistMO.isFavorite))
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
    
    public func getGenres() -> [Genre] {
        let fetchRequest = GenreMO.identifierSortedFetchRequest
        let foundGenres = try? context.fetch(fetchRequest)
        let genres = foundGenres?.compactMap{ Genre(managedObject: $0) }
        return genres ?? [Genre]()
    }
    
    public func getArtists() -> [Artist] {
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        let foundArtists = try? context.fetch(fetchRequest)
        let artists = foundArtists?.compactMap{ Artist(managedObject: $0) }
        return artists ?? [Artist]()
    }
    
    public func getFavoriteArtists() -> [Artist] {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == TRUE", #keyPath(ArtistMO.isFavorite))
        ])
        let foundArtists = try? context.fetch(fetchRequest)
        let artists = foundArtists?.compactMap{ Artist(managedObject: $0) }
        return artists ?? [Artist]()
    }
    
    public func getAlbums() -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getAlbums(whichContainsSongsWithArtist artist: Artist) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            self.getFetchPredicate(forArtist: artist),
            AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist)
        ])
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getFavoriteAlbums() -> [Album] {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isFavorite))
        ])
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getRecentAlbumsForCarPlay() -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            getFetchPredicate(albumsDisplayFilter: .recentlyAdded),
            getFetchPredicate(onlyCachedAlbums: true),
        ])
        fetchRequest.fetchLimit = Self.carPlayMaxElements
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }

    public func getPodcasts() -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }

    public func getPodcastsForCarPlay() -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            getFetchPredicate(onlyCachedPodcasts: true),
        ])
        fetchRequest.fetchLimit = Self.carPlayMaxElements
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }

    public func getRemoteAvailablePodcasts() -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
            getFetchPredicate(onlyCachedPodcasts: true),
        ])
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }

    public func getPodcastEpisodes() -> [PodcastEpisode] {
        let fetchRequest = PodcastEpisodeMO.identifierSortedFetchRequest
        let foundPodcastEpisodes = try? context.fetch(fetchRequest)
        let podcastEpisodes = foundPodcastEpisodes?.compactMap{ PodcastEpisode(managedObject: $0) }
        return podcastEpisodes ?? [PodcastEpisode]()
    }
    
    public func getSongs() -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getSongsForCompleteLibraryDownload() -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            NSPredicate(format: "%K == nil", #keyPath(SongMO.file)),
            NSPredicate(format: "%K == nil", #keyPath(SongMO.download))
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getFavoriteSongs() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isFavorite))
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getRecentSongs() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isRecentlyAdded))
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getRecentSongsForCarPlay() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            getFetchPredicate(onlyCachedSongs: true),
            NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isRecentlyAdded))
        ])
        fetchRequest.fetchLimit = Self.carPlayMaxElements
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getFirstUploadableScrobbleEntry() -> ScrobbleEntry? {
        let fetchRequest = ScrobbleEntryMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ScrobbleEntryMO.date), ascending: true) // oldest first
        ]
        fetchRequest.predicate = NSPredicate(format: "%K == FALSE", #keyPath(ScrobbleEntryMO.isUploaded))
        fetchRequest.fetchLimit = 1
        let entries = try? context.fetch(fetchRequest)
        return entries?.lazy.compactMap{ ScrobbleEntry(managedObject: $0) }.first
    }
    
    public func getPlaylists() -> [Playlist] {
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        let foundPlaylists = try? context.fetch(fetchRequest)
        let playlists = foundPlaylists?.compactMap{ Playlist(library: self, managedObject: $0) }
        return playlists ?? [Playlist]()
    }
    
    public func getPlaylistsForCarPlay(sortType: PlaylistSortType) -> [Playlist] {
        var fetchRequest = PlaylistMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = PlaylistMO.identifierSortedFetchRequest
        case .lastPlayed:
            fetchRequest = PlaylistMO.lastPlayedDateFetchRequest
        case .lastChanged:
            fetchRequest = PlaylistMO.lastChangedDateFetchRequest
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            PlaylistMO.excludeSystemPlaylistsFetchPredicate,
            getFetchPredicate(forPlaylistSearchCategory: .cached)
        ])
        fetchRequest.fetchLimit = Self.carPlayMaxElements
        let foundPlaylists = try? context.fetch(fetchRequest)
        let playlists = foundPlaylists?.compactMap{ Playlist(library: self, managedObject: $0) }
        return playlists ?? [Playlist]()
    }
    
    public func getLogEntries() -> [LogEntry] {
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
        if playerMO.podcastPlaylist == nil {
            playerMO.podcastPlaylist = PlaylistMO(context: context)
            saveContext()
        }
        
        let userQueuePlaylist = Playlist(library: self, managedObject: playerMO.userQueuePlaylist!)
        let contextPlaylist = Playlist(library: self, managedObject: playerMO.contextPlaylist!)
        let shuffledContextPlaylist = Playlist(library: self, managedObject: playerMO.shuffledContextPlaylist!)
        let podcastPlaylist = Playlist(library: self, managedObject: playerMO.podcastPlaylist!)
        
        if shuffledContextPlaylist.items.count != contextPlaylist.items.count {
            shuffledContextPlaylist.removeAllItems()
            shuffledContextPlaylist.append(playables: contextPlaylist.playables)
            shuffledContextPlaylist.shuffle()
        }
        
        playerData = PlayerData(library: self, managedObject: playerMO, userQueue: userQueuePlaylist, contextQueue: contextPlaylist, shuffledContextQueue: shuffledContextPlaylist, podcastQueue: podcastPlaylist)
        
        return playerData
    }

    func getGenre(id: String) -> Genre? {
        let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let genres = try? context.fetch(fetchRequest)
        return genres?.lazy.compactMap{ Genre(managedObject: $0) }.first
    }
    
    private func getGenres(id: String) -> [Genre] {
        let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(GenreMO.id), NSString(string: id))
        let genres = try? context.fetch(fetchRequest)
        return genres?.compactMap{ Genre(managedObject: $0) } ?? [Genre]()
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
    
    private func getArtists(id: String) -> [Artist] {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), NSString(string: id))
        let artists = try? context.fetch(fetchRequest)
        return artists?.compactMap{ Artist(managedObject: $0) } ?? [Artist]()
    }
    
    func getArtistLocal(name: String) -> Artist? {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(ArtistMO.id), ""),
            NSPredicate(format: "%K == %@", #keyPath(ArtistMO.name), NSString(string: name))
        ])
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
    
    private func getAlbums(id: String) -> [Album] {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(AlbumMO.id), NSString(string: id))
        let albums = try? context.fetch(fetchRequest)
        return albums?.compactMap{ Album(managedObject: $0) } ?? [Album]()
    }
    
    func getAlbumWithoutSyncedSongs() -> Album? {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %i", #keyPath(AlbumMO.remoteStatus), RemoteStatus.available.rawValue),
            NSPredicate(format: "%K == FALSE", #keyPath(AlbumMO.isSongsMetaDataSynced))
        ])
        fetchRequest.fetchLimit = 1
        let albums = try? context.fetch(fetchRequest)
        return albums?.lazy.compactMap{ Album(managedObject: $0) }.first
    }

    func getPodcast(id: String) -> Podcast? {
        let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let podcasts = try? context.fetch(fetchRequest)
        return podcasts?.lazy.compactMap{ Podcast(managedObject: $0) }.first
    }
   
    private func getPodcasts(id: String) -> [Podcast] {
        let fetchRequest: NSFetchRequest<PodcastMO> = PodcastMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastMO.id), NSString(string: id))
        let podcasts = try? context.fetch(fetchRequest)
        return podcasts?.compactMap{ Podcast(managedObject: $0) } ?? [Podcast]()
    }
    
    public func getPodcastEpisode(id: String) -> PodcastEpisode? {
        let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastEpisodeMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let podcastEpisodes = try? context.fetch(fetchRequest)
        return podcastEpisodes?.lazy.compactMap{ PodcastEpisode(managedObject: $0) }.first
    }
    
    private func getPodcastEpisodes(id: String) -> [PodcastEpisode] {
        let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PodcastEpisodeMO.id), NSString(string: id))
        let podcastEpisodes = try? context.fetch(fetchRequest)
        return podcastEpisodes?.compactMap{ PodcastEpisode(managedObject: $0) } ?? [PodcastEpisode]()
    }
    
    public func getSong(id: String) -> Song? {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(SongMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let songs = try? context.fetch(fetchRequest)
        return songs?.lazy.compactMap{ Song(managedObject: $0) }.first
    }
    
    private func getSongs(id: String) -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(SongMO.id), NSString(string: id))
        let songs = try? context.fetch(fetchRequest)
        return songs?.compactMap{ Song(managedObject: $0) } ?? [Song]()
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

    private func getPlaylists(id: String) -> [Playlist] {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PlaylistMO.id), NSString(string: id))
        let playlists = try? context.fetch(fetchRequest)
        return playlists?.compactMap{ Playlist(library: self, managedObject: $0) } ?? [Playlist]()
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
    
    public func getArtworksForCompleteLibraryDownload() -> [Artwork] {
        let fetchRequest = ArtworkMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.imageData)),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.download)),
                NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.download.errorDate)),
            ]),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue))),
                NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.FetchError.rawValue))),
            ])
        ])
            
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
    
    public func cleanStorage() {
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
    
    public func saveContext () {
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
