//
//  LibraryStorage.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import os.log

protocol PlayableFileCachable {
    func getFileURL(forPlayable playable: AbstractPlayable) -> URL?
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
    public static var carPlayMaxElements = 200
    
    static let entitiesToDelete = [
        Genre.typeName,
        Artist.typeName,
        Album.typeName,
        Song.typeName,
        PlayableFile.typeName,
        Artwork.typeName,
        EmbeddedArtwork.typeName,
        Playlist.typeName,
        PlaylistItem.typeName,
        PlayerData.entityName,
        LogEntry.typeName,
        MusicFolder.typeName,
        Directory.typeName,
        Podcast.typeName,
        PodcastEpisode.typeName,
        Radio.typeName,
        Download.typeName,
        ScrobbleEntry.typeName,
        SearchHistoryItem.typeName]
    private let log = OSLog(subsystem: "Amperfy", category: "LibraryStorage")
    private var context: NSManagedObjectContext
    private let fileManager = CacheFileManager.shared
    
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
        libraryInfo.cachedSongSize = fileManager.playableCacheSize.asByteString
        libraryInfo.genreCount = genreCount
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
    
    public var artworkCount: Int {
        return (try? context.count(for: ArtworkMO.fetchRequest())) ?? 0
    }

    public var artworkNotCheckedCount: Int {
        let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.relFilePath)),
            NSPredicate(format: "%K == %@", #keyPath(ArtworkMO.status), NSNumber(integerLiteral: Int(ImageStatus.NotChecked.rawValue))),
        ])
        return (try? context.count(for: request)) ?? 0
    }

    public var cachedArtworkCount: Int {
        let request: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.relFilePath))
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
        request.predicate = getFetchPredicate(onlyCachedSongs: true)
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
        request.predicate = getFetchPredicate(onlyCachedPodcastEpisodes: true)
        return (try? context.count(for: request)) ?? 0
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
    
    func createRadio() -> Radio {
        let radioMO = RadioMO(context: context)
        return Radio(managedObject: radioMO)
    }
    
    func createScrobbleEntry() -> ScrobbleEntry {
        let scrobbleEntryMO = ScrobbleEntryMO(context: context)
        return ScrobbleEntry(managedObject: scrobbleEntryMO)
    }
    
    func deleteRadio(_ radio: Radio) {
        context.delete(radio.managedObject)
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
        if let relFilePath = playable.relFilePath,
           fileManager.fileExits(relFilePath: relFilePath),
           let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
            do {
                try fileManager.removeItem(at: absFilePath)
            } catch {
                os_log("File for <%s> could not be removed at <%s>", log: log, type: .info, playable.displayString, absFilePath.path)
            }
        }
        playable.contentTypeTranscoded = nil
        playable.relFilePath = nil
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
    
    /// binary data is saved in file manager. Old binary data is ensured to be deleted this way.
    public func deleteBinaryPlayableFileSavedInCoreData() {
        clearStorage(ofType: PlayableFile.typeName)
    }

    public func deletePlayableCachePaths() {
        deleteBinaryPlayableFileSavedInCoreData()
        let songs = getCachedSongs()
        songs.forEach{ $0.relFilePath = nil }
        let episodes = getCachedPodcastEpisodes()
        episodes.forEach{ $0.relFilePath = nil }
    }
    
    public func deleteRemoteArtworkCachePaths() {
        let fetchRequest = ArtworkMO.fetchRequest()
        guard let artworksMO = try? context.fetch(fetchRequest) else { return }
        for artworkMO in artworksMO {
            artworkMO.status = ImageStatus.NotChecked.rawValue
            artworkMO.relFilePath = nil
        }
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
        playlist.removeAllItems()
        context.delete(playlist.managedObject)
    }
    
    func createPlaylistItem(playable: AbstractPlayable) -> PlaylistItem {
        let itemMO = PlaylistItemMO(context: context)
        itemMO.playable = playable.playableManagedObject
        return PlaylistItem(library: self, managedObject: itemMO)
    }
    
    func deletePlaylistItem(item: PlaylistItem) {
        context.delete(item.managedObject)
    }
    func deletePlaylistItemMO(item: PlaylistItemMO) {
        context.delete(item)
    }

    /// Download Fetch Cache
    private var downloadFetchCacheId : [String: NSManagedObjectID] = [:]
    private var downloadFetchCacheUrl : [String: NSManagedObjectID] = [:]
    
    func createDownload(id: String) -> Download {
        let download = Download(managedObject: DownloadMO(context: context))
        download.id = id
        return download
    }
    
    func setDownloadUrl(download: Download, url: URL) {
        downloadFetchCacheUrl[url.absoluteString] = download.managedObject.objectID
        download.setURL(url)
    }
    
    func getDownload(id: String) -> Download? {
        let downloadObjectId : NSManagedObjectID? = downloadFetchCacheId[id]

        if let downloadObjectId = downloadObjectId {
            let object = context.object(with: downloadObjectId)
            return Download(managedObject: object as! DownloadMO)
        } else {
            let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DownloadMO.id), NSString(string: id))
            fetchRequest.fetchLimit = 1
            let downloads = try? context.fetch(fetchRequest)
            if let downloadMO = downloads?.lazy.first {
                let download = Download(managedObject: downloadMO)
                downloadFetchCacheId[download.id] = downloadMO.objectID
                if let urlString = download.url?.absoluteString {
                    downloadFetchCacheUrl[urlString] = downloadMO.objectID
                }
                return download
            }
        }
        return nil
    }
    
    func getDownload(url: String) -> Download? {
        let downloadObjectId : NSManagedObjectID? = downloadFetchCacheUrl[url]

        if let downloadObjectId = downloadObjectId {
            let object = context.object(with: downloadObjectId)
            return Download(managedObject: object as! DownloadMO)
        } else {
            let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(DownloadMO.urlString), NSString(string: url))
            fetchRequest.fetchLimit = 1
            let downloads = try? context.fetch(fetchRequest)
            if let downloadMO = downloads?.lazy.first {
                let download = Download(managedObject: downloadMO)
                downloadFetchCacheId[download.id] = downloadMO.objectID
                downloadFetchCacheUrl[url] = downloadMO.objectID
                return download
            }
        }
        return nil
    }
    
    func deleteDownload(_ download: Download) {
        downloadFetchCacheId[download.id] = nil
        downloadFetchCacheUrl[download.urlString] = nil
        context.delete(download.managedObject)
    }
    
    
    public func getContainer(identifier: PlayableContainerIdentifier) -> PlayableContainable? {
        guard let type = identifier.type,
              let objectID = identifier.objectID,
              let url = URL(string: objectID),
              let managedObjectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
        else { return nil}

        switch type {
        case .song:
            return Song(managedObject: context.object(with: managedObjectID) as! SongMO)
        case .podcastEpisode:
            return PodcastEpisode(managedObject: context.object(with: managedObjectID) as! PodcastEpisodeMO)
        case .album:
            return Album(managedObject: context.object(with: managedObjectID) as! AlbumMO)
        case .artist:
            return Artist(managedObject: context.object(with: managedObjectID) as! ArtistMO)
        case .genre:
            return Genre(managedObject: context.object(with: managedObjectID) as! GenreMO)
        case .playlist:
            return Playlist(library: self, managedObject: context.object(with: managedObjectID) as! PlaylistMO)
        case .podcast:
            return Podcast(managedObject: context.object(with: managedObjectID) as! PodcastMO)
        case .directory:
            return Directory(managedObject: context.object(with: managedObjectID) as! DirectoryMO)
        case .radio:
            return Radio(managedObject: context.object(with: managedObjectID) as! RadioMO)
        }
    }
    
    public func createOrUpdateSearchHistory(container: PlayableContainable) -> SearchHistoryItem {
        let fetchRequest: NSFetchRequest<SearchHistoryItemMO> = SearchHistoryItemMO.fetchRequest()
        var predicate: NSPredicate?
        
        if let song = container as? Song {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedLibraryEntity), song.managedObject)
        } else if let episode = container as? PodcastEpisode {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedLibraryEntity), episode.managedObject)
        } else if let album = container as? Album {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedLibraryEntity), album.managedObject)
        } else if let artist = container as? Artist {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedLibraryEntity), artist.managedObject)
        } else if let podcast = container as? Podcast {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedLibraryEntity), podcast.managedObject)
        } else if let playlist = container as? Playlist {
            predicate = NSPredicate(format: "%K == %@", #keyPath(SearchHistoryItemMO.searchedPlaylist), playlist.managedObject)
        }
        
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        let searchHistoryMO = try? context.fetch(fetchRequest)
        if let searchHistory = searchHistoryMO?.lazy.compactMap({ SearchHistoryItem(managedObject: $0) }).first {
            // update the existing one
            searchHistory.date = Date()
            return searchHistory
        } else {
            // create a new item
            let itemMO = SearchHistoryItemMO(context: context)
            let item = SearchHistoryItem(managedObject: itemMO)
            item.date = Date()
            item.searchedPlayableContainable = container
            return item
        }
    }
    
    public func deleteSearchHistory() {
        clearStorage(ofType: SearchHistoryItem.typeName)
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
    
    func getFetchPredicateForOrphanedPlaylistItems() -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(PlaylistItemMO.playlist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistItemMO.playable))
        ])
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
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedAlbums: Bool) -> NSPredicate {
        if onlyCachedAlbums {
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(forSongsOfArtistWithCommonAlbum artist: Artist) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(SongMO.album.artist), artist.managedObject.objectID)
    }
    
    func getFetchPredicate(onlyCachedPlaylistItems: Bool) -> NSPredicate {
        if onlyCachedPlaylistItems {
            return NSPredicate(format: "%K != nil", #keyPath(PlaylistItemMO.playable.relFilePath))
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedSongs: Bool) -> NSPredicate {
        if onlyCachedSongs {
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K != nil", #keyPath(SongMO.relFilePath))
            ])
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedPodcasts: Bool) -> NSPredicate {
        if onlyCachedPodcasts {
            return NSPredicate(format: "SUBQUERY(episodes, $episode, $episode.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedPodcastEpisodes: Bool) -> NSPredicate {
        if onlyCachedPodcastEpisodes {
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.relFilePath))
            ])
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreArtists: Bool) -> NSPredicate {
        if onlyCachedGenreArtists {
            return NSPredicate(format: "SUBQUERY(artists, $artist, ANY $artist.songs.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreAlbums: Bool) -> NSPredicate {
        if onlyCachedGenreAlbums {
            return NSPredicate(format: "SUBQUERY(albums, $album, ANY $album.songs.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(onlyCachedGenreSongs: Bool) -> NSPredicate {
        if onlyCachedGenreSongs {
            return NSPredicate(format: "SUBQUERY(songs, $song, $song.relFilePath != nil) .@count > 0")
        } else {
            return NSPredicate.alwaysTrue
        }
    }
    
    func getFetchPredicate(songsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch songsDisplayFilter {
        case .all, .newest, .recent:
            return NSPredicate.alwaysTrue
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(SongMO.isFavorite))
        }
    }
    
    func getFetchPredicate(albumsDisplayFilter: DisplayCategoryFilter) -> NSPredicate {
        switch albumsDisplayFilter {
        case .all:
            return NSPredicate.alwaysTrue
        case .newest:
            return NSPredicate(format: "%K > 0", #keyPath(AlbumMO.newestIndex))
        case .recent:
            return NSPredicate(format: "%K > 0", #keyPath(AlbumMO.recentIndex))
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(AlbumMO.isFavorite))
        }
    }

    func getFetchPredicate(artistsDisplayFilter: ArtistCategoryFilter) -> NSPredicate {
        switch artistsDisplayFilter {
        case .all:
            return NSPredicate.alwaysTrue
        case .albumArtists:
            return NSPredicate(format: "%K.@count > 0", #keyPath(ArtistMO.albums))
        case .favorites:
            return NSPredicate(format: "%K == TRUE", #keyPath(ArtistMO.isFavorite))
        }
    }
    
    func getFetchPredicate(forPlaylistSearchCategory playlistSearchCategory: PlaylistSearchCategory) -> NSPredicate {
        switch playlistSearchCategory {
        case .all:
            return NSPredicate.alwaysTrue
        case .cached:
            return NSPredicate(format: "SUBQUERY(items, $item, $item.playable.relFilePath != nil) .@count > 0")
        case .userOnly:
            return NSPredicate(format: "NOT (%K BEGINSWITH %@)", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        case .smartOnly:
            return NSPredicate(format: "%K BEGINSWITH %@", #keyPath(PlaylistMO.id), Playlist.smartPlaylistIdPrefix)
        }
    }
    
    public func getGenres(isFaultsOptimized: Bool = false) -> [Genre] {
        let fetchRequest = GenreMO.identifierSortedFetchRequest
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = GenreMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
        let foundGenres = try? context.fetch(fetchRequest)
        let genres = foundGenres?.compactMap{ Genre(managedObject: $0) }
        return genres ?? [Genre]()
    }
    
    public func getArtists(isFaultsOptimized: Bool = false) -> [Artist] {
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = ArtistMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
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
    
    public func getAlbumArtists() -> [Artist] {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            getFetchPredicate(artistsDisplayFilter: .albumArtists)
        ])
        let foundArtists = try? context.fetch(fetchRequest)
        let artists = foundArtists?.compactMap{ Artist(managedObject: $0) }
        return artists ?? [Artist]()
    }
    
    public func getAlbums(isFaultsOptimized: Bool = false) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getNewestAlbums(offset: Int = 0, count: Int = 50) -> [Album] {
        let fetchRequest = AlbumMO.newestSortedFetchRequest
        fetchRequest.predicate = getFetchPredicate(albumsDisplayFilter: .newest)
        fetchRequest.fetchOffset = offset
        fetchRequest.fetchLimit = count
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getRecentAlbums(offset: Int = 0, count: Int = 50) -> [Album] {
        let fetchRequest = AlbumMO.recentSortedFetchRequest
        fetchRequest.predicate = getFetchPredicate(albumsDisplayFilter: .recent)
        fetchRequest.fetchOffset = offset
        fetchRequest.fetchLimit = count
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getAlbums(whichContainsSongsWithArtist artist: Artist, onlyCached: Bool = false) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            getFetchPredicate(onlyCachedAlbums: onlyCached),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                self.getFetchPredicate(forArtist: artist),
                AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist),
            ])
        ])
        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?.compactMap{ Album(managedObject: $0) }
        return albums ?? [Album]()
    }
    
    public func getRandomAlbums(count: Int, onlyCached: Bool) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        if onlyCached {
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                getFetchPredicate(onlyCachedAlbums: true),
            ])
        } else {
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                getFetchPredicate(onlyCachedAlbums: true),
            ])
        }

        let foundAlbums = try? context.fetch(fetchRequest)
        let albums = foundAlbums?[randomPick: count].compactMap{ Album(managedObject: $0) }
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
    
    public func getPodcasts(isFaultsOptimized: Bool = false) -> [Podcast] {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = PodcastMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
        let foundPodcasts = try? context.fetch(fetchRequest)
        let podcasts = foundPodcasts?.compactMap{ Podcast(managedObject: $0) }
        return podcasts ?? [Podcast]()
    }
    
    public func getNewestPodcastEpisode(count: Int) -> [PodcastEpisode] {
        let fetchRequest = PodcastEpisodeMO.publishedDateSortedFetchRequest
        fetchRequest.predicate = getFetchPredicateForUserAvailableEpisodes()
        fetchRequest.fetchLimit = count
        let foundPodcastEpisodes = try? context.fetch(fetchRequest)
        let podcastEpisodes = foundPodcastEpisodes?.compactMap{ PodcastEpisode(managedObject: $0) }
        return podcastEpisodes ?? [PodcastEpisode]()
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
    
    public func getCachedPodcastEpisodes() -> [PodcastEpisode] {
        let fetchRequest = PodcastEpisodeMO.identifierSortedFetchRequest
        fetchRequest.predicate = getFetchPredicate(onlyCachedPodcastEpisodes: true)
        let foundPodcastEpisodes = try? context.fetch(fetchRequest)
        let podcastEpisodes = foundPodcastEpisodes?.compactMap{ PodcastEpisode(managedObject: $0) }
        return podcastEpisodes ?? [PodcastEpisode]()
    }
    
    /// depricated: file data is now in file manager
    public func getCachedPodcastEpisodesThatHaveFileDataInCoreData() -> [PodcastEpisode] {
        let fetchRequest = PodcastEpisodeMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(PodcastEpisodeMO.file))
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
    
    public func getRadios() -> [Radio] {
        let fetchRequest = RadioMO.identifierSortedFetchRequest
        fetchRequest.predicate = RadioMO.excludeServerDeleteRadiosFetchPredicate
        let foundRadios = try? context.fetch(fetchRequest)
        let radios = foundRadios?.compactMap{ Radio(managedObject: $0) }
        return radios ?? [Radio]()
    }
    
    public func getSearchHistory() -> [SearchHistoryItem] {
        let fetchRequest = SearchHistoryItemMO.searchDateFetchRequest
        fetchRequest.predicate = SearchHistoryItemMO.excludeEmptyItemsFetchPredicate
        let foundHistory = try? context.fetch(fetchRequest)
        let history = foundHistory?.compactMap{ SearchHistoryItem(managedObject: $0) }
        return history ?? [SearchHistoryItem]()
    }
    
    public func getSearchArtistsPredicate(searchText: String, onlyCached: Bool, displayFilter: ArtistCategoryFilter) -> NSPredicate {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                self.getFetchPredicate(onlyCachedArtists: true)
            ]),
            ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
            self.getFetchPredicate(onlyCachedArtists: onlyCached),
            self.getFetchPredicate(artistsDisplayFilter: displayFilter)
        ])
        return predicate
    }
    
    public func searchArtists(searchText: String, onlyCached: Bool, displayFilter: ArtistCategoryFilter) -> [Artist] {
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        fetchRequest.predicate = getSearchArtistsPredicate(searchText: searchText, onlyCached: onlyCached, displayFilter: displayFilter)
        let found = try? context.fetch(fetchRequest)
        let wrapped = found?.compactMap{ Artist(managedObject: $0) }
        return wrapped ?? [Artist]()
    }
    
    public func getSearchAlbumsPredicate(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) -> NSPredicate {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                self.getFetchPredicate(onlyCachedAlbums: true)
            ]),
            AlbumMO.getIdentifierBasedSearchPredicate(searchText: searchText),
            self.getFetchPredicate(onlyCachedAlbums: onlyCached),
            self.getFetchPredicate(albumsDisplayFilter: displayFilter)
        ])
        return predicate
    }
    
    public func searchAlbums(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) -> [Album] {
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = getSearchAlbumsPredicate(searchText: searchText, onlyCached: onlyCached, displayFilter: displayFilter)
        let found = try? context.fetch(fetchRequest)
        let wrapped = found?.compactMap{ Album(managedObject: $0) }
        return wrapped ?? [Album]()
    }
    
    public func getSearchPlaylistsPredicate(searchText: String, playlistSearchCategory: PlaylistSearchCategory) -> NSPredicate {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            PlaylistMO.excludeSystemPlaylistsFetchPredicate,
            PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
            self.getFetchPredicate(forPlaylistSearchCategory: playlistSearchCategory)
        ])
        return predicate
    }
    
    public func searchPlaylists(searchText: String, playlistSearchCategory: PlaylistSearchCategory) -> [Playlist] {
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        fetchRequest.predicate = getSearchPlaylistsPredicate(searchText: searchText, playlistSearchCategory: playlistSearchCategory)
        let found = try? context.fetch(fetchRequest)
        let wrapped = found?.compactMap{ Playlist(library: self, managedObject: $0) }
        return wrapped ?? [Playlist]()
    }
    
    public func getSearchRadiosPredicate(searchText: String) -> NSPredicate {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            RadioMO.excludeServerDeleteRadiosFetchPredicate,
            RadioMO.getIdentifierBasedSearchPredicate(searchText: searchText)
        ])
        return predicate
    }
    
    public func getSearchSongsPredicate(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) -> NSPredicate {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
            self.getFetchPredicate(onlyCachedSongs: onlyCached),
            self.getFetchPredicate(songsDisplayFilter: displayFilter)
        ])
        return predicate
    }
    
    public func searchSongs(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = getSearchSongsPredicate(searchText: searchText, onlyCached: onlyCached, displayFilter: displayFilter)
        let found = try? context.fetch(fetchRequest)
        let wrapped = found?.compactMap{ Song(managedObject: $0) }
        return wrapped ?? [Song]()
    }
    
    
    public func getSongs(whichContainsSongsWithArtist artist: Artist, onlyCached: Bool = false) -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                getFetchPredicate(forArtist: artist),
                getFetchPredicate(onlyCachedSongs: onlyCached)
            ]),
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                getFetchPredicate(forSongsOfArtistWithCommonAlbum: artist),
                getFetchPredicate(onlyCachedSongs: onlyCached)
            ])
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getRandomSongs(count: Int = 100, onlyCached: Bool) -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            getFetchPredicate(onlyCachedSongs: onlyCached)
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?[randomPick: count].compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    public func getSongsForCompleteLibraryDownload() -> [Song] {
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            NSPredicate(format: "%K == nil", #keyPath(SongMO.relFilePath)),
            NSPredicate(format: "%K == nil", #keyPath(SongMO.download))
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    /// get all "old" song which contain the binary data in core data
    func getPlayableFiles() -> [PlayableFile] {
        let fetchRequest = PlayableFileMO.fetchRequest()
        let founds = try? context.fetch(fetchRequest)
        let files = founds?.compactMap{ PlayableFile(managedObject: $0) }
        return files ?? [PlayableFile]()
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
    
    public func getCachedSongs() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            getFetchPredicate(onlyCachedSongs: true)
        ])
        let foundSongs = try? context.fetch(fetchRequest)
        let songs = foundSongs?.compactMap{ Song(managedObject: $0) }
        return songs ?? [Song]()
    }
    
    /// depricated: file data is now in file manager
    public func getCachedSongsThatHaveFileDataInCoreData() -> [Song] {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(SongMO.file))
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
    
    public func getPlaylists(isFaultsOptimized: Bool = false, areSystemPlaylistsIncluded: Bool = false) -> [Playlist] {
        let fetchRequest = PlaylistMO.identifierSortedFetchRequest
        if !areSystemPlaylistsIncluded {
            fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        }
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = PlaylistMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
        let foundPlaylists = try? context.fetch(fetchRequest)
        let playlists = foundPlaylists?.compactMap{ Playlist(library: self, managedObject: $0) }
        return playlists ?? [Playlist]()
    }
    
    public func getPlaylistItems(playlist: Playlist) -> [PlaylistItemMO] {
        let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
        fetchRequest.predicate = getFetchPredicate(forPlaylist: playlist)
        let foundPlaylistItems = try? context.fetch(fetchRequest)
        return foundPlaylistItems ?? [PlaylistItemMO]()
    }
    
    public func getPlaylistItemOrphans() -> [PlaylistItem] {
        let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
        fetchRequest.predicate = getFetchPredicateForOrphanedPlaylistItems()
        let foundPlaylistItems = try? context.fetch(fetchRequest)
        let items = foundPlaylistItems?.compactMap{ PlaylistItem(library: self, managedObject: $0) }
        return items ?? [PlaylistItem]()
    }
    
    public func getLogEntries() -> [LogEntry] {
        let fetchRequest: NSFetchRequest<LogEntryMO> = LogEntryMO.creationDateSortedFetchRequest
        let foundEntries = try? context.fetch(fetchRequest)
        let entries = foundEntries?.compactMap{ LogEntry(managedObject: $0) }
        return entries ?? [LogEntry]()
    }
    
    func getPlayerData() -> PlayerData {
        let fetchRequest = PlayerMO.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = PlayerMO.relationshipKeyPathsForPrefetching
        fetchRequest.returnsObjectsAsFaults = false
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
        
        if shuffledContextPlaylist.managedObject.items.count != contextPlaylist.managedObject.items.count {
            shuffledContextPlaylist.removeAllItems()
            shuffledContextPlaylist.append(playables: contextPlaylist.playables)
            shuffledContextPlaylist.shuffle()
        }
        
        playerData = PlayerData(library: self, managedObject: playerMO, userQueue: userQueuePlaylist, contextQueue: contextPlaylist, shuffledContextQueue: shuffledContextPlaylist, podcastQueue: podcastPlaylist)
        
        return playerData
    }

    public func getGenre(id: String) -> Genre? {
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
    
    public func getArtist(id: String) -> Artist? {
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
    
    public func getAlbum(id: String, isDetailFaultResolution: Bool) -> Album? {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(AlbumMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        if isDetailFaultResolution {
            fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO.relationshipKeyPathsForPrefetchingDetailed
        } else {
            fetchRequest.relationshipKeyPathsForPrefetching = AlbumMO.relationshipKeyPathsForPrefetching
        }
        fetchRequest.returnsObjectsAsFaults = false
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

    public func getPodcast(id: String) -> Podcast? {
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
    
    public func getRadio(id: String) -> Radio? {
        let fetchRequest: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RadioMO.id), NSString(string: id))
        fetchRequest.fetchLimit = 1
        let radios = try? context.fetch(fetchRequest)
        return radios?.lazy.compactMap{ Radio(managedObject: $0) }.first
    }
    
    func getFileURL(forPlayable playable: AbstractPlayable) -> URL? {
        var absFileURL: URL?
        if let relFilePath = playable.relFilePath {
            absFileURL = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
        } else {
            os_log("File URL was not able to retrieve for: %s", log: log, type: .error, playable.displayString)
        }
        return absFileURL
    }
    
    /// depricated: file data is now in file manager
    public func getFile(forPlayable playable: AbstractPlayable) -> PlayableFile? {
        let fetchRequest: NSFetchRequest<PlayableFileMO> = PlayableFileMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PlayableFileMO.info.id), NSString(string: playable.id))
        fetchRequest.fetchLimit = 1
        let playableFiles = try? context.fetch(fetchRequest)
        return playableFiles?.lazy.compactMap{ PlayableFile(managedObject: $0) }.first
    }
    
    /// depricated: file data is now in file manager
    public func getArtworkData(forArtworkRemoteInfo: ArtworkRemoteInfo) -> Data? {
        var data: Data?
        autoreleasepool {
            let duplicateArtwork = getArtwork(remoteInfo: forArtworkRemoteInfo)
            data = duplicateArtwork?.managedObject.imageData
        }
        return data
    }
    
    /// depricated: file data is now in file manager
    public func getEmbeddedArtworkData(forOwner playable: AbstractPlayable) -> Data? {
        var data: Data?
        autoreleasepool {
            let fetchRequest: NSFetchRequest<EmbeddedArtworkMO> = EmbeddedArtworkMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(EmbeddedArtworkMO.owner.id), NSString(string: playable.id))
            fetchRequest.fetchLimit = 1
            let embeddedArtworks = try? self.context.fetch(fetchRequest)
            data = embeddedArtworks?.lazy.compactMap{ $0.imageData }.first
        }
        return data
    }
    
    public func getEmbeddedArtwork(forOwner playable: AbstractPlayable) -> EmbeddedArtwork? {
        let fetchRequest: NSFetchRequest<EmbeddedArtworkMO> = EmbeddedArtworkMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(EmbeddedArtworkMO.owner.id), NSString(string: playable.id))
        fetchRequest.fetchLimit = 1
        let embeddedArtworks = try? self.context.fetch(fetchRequest)
        return embeddedArtworks?.lazy.compactMap{ EmbeddedArtwork(managedObject: $0) }.first
    }
    
    /// depricated: file data is now in file manager
    public func getFileSizeOfPlayableFileInByte(playableFile: PlayableFile) -> Int64 {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: PlayableFile.typeName)
        guard let ownerId = playableFile.info?.id else { return 0 }
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PlayableFileMO.info.id), NSString(string: ownerId))
        fetchRequest.propertiesToFetch = [#keyPath(PlayableFileMO.data)]
        fetchRequest.resultType = .dictionaryResultType
        let foundPlayableFiles = (try? context.fetch(fetchRequest)) ?? [NSDictionary]()
        let file = foundPlayableFiles.lazy.compactMap{ $0[#keyPath(PlayableFileMO.data)] as? NSData }.first
        return file?.sizeInByte ?? 0
     }

    public func getPlaylist(id: String) -> Playlist? {
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
    
    /// depricated: get all "old" embedded artworks which contain the image in core data
    func getEmbeddedArtworksContainingBinaryData() -> [EmbeddedArtwork] {
        let fetchRequest: NSFetchRequest<EmbeddedArtworkMO> = EmbeddedArtworkMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(EmbeddedArtworkMO.imageData)),
        ])
        let founds = try? context.fetch(fetchRequest)
        let artworks = founds?.compactMap{ EmbeddedArtwork(managedObject: $0) }
        return artworks ?? [EmbeddedArtwork]()
    }
    
    func getArtworks() -> [Artwork] {
        let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        let founds = try? context.fetch(fetchRequest)
        let artworks = founds?.compactMap{ Artwork(managedObject: $0) }
        return artworks ?? [Artwork]()
    }
    
    /// depricated: get all "old" artworks which contain the image in core data
    func getArtworksContainingBinaryData() -> [Artwork] {
        let fetchRequest: NSFetchRequest<ArtworkMO> = ArtworkMO.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(ArtworkMO.imageData)),
        ])
        let founds = try? context.fetch(fetchRequest)
        let artworks = founds?.compactMap{ Artwork(managedObject: $0) }
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
            NSPredicate(format: "%K == nil", #keyPath(ArtworkMO.relFilePath)),
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
    
    func getMusicFolders(isFaultsOptimized: Bool = false) -> [MusicFolder] {
        let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = MusicFolderMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
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
    
    func getDirectories(isFaultsOptimized: Bool = false) -> [Directory] {
        let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
        if isFaultsOptimized {
            fetchRequest.relationshipKeyPathsForPrefetching = DirectoryMO.relationshipKeyPathsForPrefetching
            fetchRequest.returnsObjectsAsFaults = false
        }
        let directories = try? context.fetch(fetchRequest)
        return directories?.lazy.compactMap{ Directory(managedObject: $0) } ?? [Directory]()
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
