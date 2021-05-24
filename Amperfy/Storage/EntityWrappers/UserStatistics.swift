import Foundation
import CoreData

public enum UserActionUsed {
    case
    airplay,
    alertGoToAlbum,
    alertGoToArtist,
    changePlayerDisplayStyle,
    playerOptions,
    playerSeek
}

public enum ViewToVisit {
    case
    albumDetail,
    albums,
    artistDetail,
    artists,
    downloads,
    eventLog,
    genreDetail,
    genres,
    library,
    license,
    playlistDetail,
    playlists,
    playlistSelector,
    popupPlayer,
    search,
    settings,
    settingsLibrary,
    settingsPlayer,
    settingsServer,
    settingsSupport,
    songs
}

public class UserStatistics {
    
    let managedObject: UserStatisticsMO
    let libraryStorage: LibraryStorage
    
    init(managedObject: UserStatisticsMO, libraryStorage: LibraryStorage) {
        self.managedObject = managedObject
        self.libraryStorage = libraryStorage
    }
    
    var appVersion: String {
        return managedObject.appVersion
    }
    
    var creationDate: Date {
        return managedObject.creationDate
    }
    
    func sessionStarted() {
        self.managedObject.appSessionsStartedCount += 1
        libraryStorage.saveContext()
    }
    
    func visited(_ visitedView: ViewToVisit) {
        switch visitedView {
        case .albumDetail:
            self.managedObject.visitedAlbumDetailCount += 1
        case .albums:
            self.managedObject.visitedAlbumsCount += 1
        case .artistDetail:
            self.managedObject.visitedArtistDetailCount += 1
        case .artists:
            self.managedObject.visitedArtistsCount += 1
        case .downloads:
            self.managedObject.visitedDownloadsCount += 1
        case .eventLog:
            self.managedObject.visitedEventLogCount += 1
        case .genreDetail:
            self.managedObject.visitedGenreDetailCount += 1
        case .genres:
            self.managedObject.visitedGenresCount += 1
        case .library:
            self.managedObject.visitedLibraryCount += 1
        case .license:
            self.managedObject.visitedLicenseCount += 1
        case .playlistDetail:
            self.managedObject.visitedPlaylistDetailCount += 1
        case .playlists:
            self.managedObject.visitedPlaylistsCount += 1
        case .playlistSelector:
            self.managedObject.visitedPlaylistSelectorCount += 1
        case .popupPlayer:
            self.managedObject.visitedPopupPlayerCount += 1
        case .search:
            self.managedObject.visitedSearchCount += 1
        case .settings:
            self.managedObject.visitedSettingsCount += 1
        case .settingsLibrary:
            self.managedObject.visitedSettingsLibraryCount += 1
        case .settingsPlayer:
            self.managedObject.visitedSettingsPlayerCount += 1
        case .settingsServer:
            self.managedObject.visitedSettingsServerCount += 1
        case .settingsSupport:
            self.managedObject.visitedSettingsSupportCount += 1
        case .songs:
            self.managedObject.visitedSongsCount += 1
        }
        
        libraryStorage.saveContext()
    }
    
    func playedSong(repeatMode: RepeatMode, isShuffle: Bool) {
        switch repeatMode {
        case .off:
            self.managedObject.activeRepeatOffSongsCount += 1
        case .all:
            self.managedObject.activeRepeatAllSongsCount += 1
        case .single:
            self.managedObject.activeRepeatSingleSongsCount += 1
        }
        
        if isShuffle {
            self.managedObject.activeShuffleOnSongsCount += 1
        } else {
            self.managedObject.activeShuffleOffSongsCount += 1
        }

        libraryStorage.saveContext()
    }
    
    func playedSong(isPlayedFromCache: Bool) {
        if isPlayedFromCache {
            self.managedObject.playedSongFromCacheCount += 1
        } else {
            self.managedObject.playedSongViaStreamCount += 1
        }
        self.managedObject.playedSongsCount += 1
        libraryStorage.saveContext()
    }
    
    func usedAction(_ actionUsed: UserActionUsed) {
        switch actionUsed {
        case .airplay:
            self.managedObject.usedAirplayCount += 1
        case .alertGoToAlbum:
            self.managedObject.usedAlertGoToAlbumCount += 1
        case .alertGoToArtist:
            self.managedObject.usedAlertGoToArtistCount += 1
        case .changePlayerDisplayStyle:
            self.managedObject.usedChangePlayerDisplayStyleCount += 1
        case .playerOptions:
            self.managedObject.usedPlayerOptionsCount += 1
        case .playerSeek:
            self.managedObject.usedPlayerSeekCount += 1
        }
        
        libraryStorage.saveContext()
    }
    
    func createLogInfo() -> UserStatisticsOverview {
        var overview = UserStatisticsOverview()
        overview.appVersion = managedObject.appVersion
        overview.creationDate = managedObject.creationDate
        overview.appSessionsStartedCount = managedObject.appSessionsStartedCount
        
        var actionUsed = ActionUsedCounts()
        actionUsed.airplay = managedObject.usedAirplayCount
        actionUsed.alertGoToAlbum = managedObject.usedAlertGoToAlbumCount
        actionUsed.alertGoToArtist = managedObject.usedAlertGoToArtistCount
        actionUsed.changePlayerDisplayStyle = managedObject.usedChangePlayerDisplayStyleCount
        actionUsed.playerOptions = managedObject.usedPlayerOptionsCount
        actionUsed.playerSeek = managedObject.usedPlayerSeekCount
        overview.actionsUsedCounts = actionUsed
        
        var songPlayedCounts = SongPlayedConfigCounts()
        songPlayedCounts.playedSongsCount = managedObject.playedSongsCount
        songPlayedCounts.playedSongFromCacheCount = managedObject.playedSongFromCacheCount
        songPlayedCounts.playedSongViaStreamCount = managedObject.playedSongViaStreamCount
        songPlayedCounts.activeRepeatOffSongsCount = managedObject.activeRepeatOffSongsCount
        songPlayedCounts.activeRepeatAllSongsCount = managedObject.activeRepeatAllSongsCount
        songPlayedCounts.activeRepeatSingleSongsCount = managedObject.activeRepeatSingleSongsCount
        songPlayedCounts.activeShuffleOnSongsCount = managedObject.activeShuffleOnSongsCount
        songPlayedCounts.activeShuffleOffSongsCount = managedObject.activeShuffleOffSongsCount
        overview.songPlayedConfigCounts = songPlayedCounts
        
        var viewsVisited = ViewsVisitedCounts()
        viewsVisited.albumDetail = managedObject.visitedAlbumDetailCount
        viewsVisited.albums = managedObject.visitedAlbumsCount
        viewsVisited.artistDetail = managedObject.visitedArtistDetailCount
        viewsVisited.artists = managedObject.visitedArtistsCount
        viewsVisited.downloads = managedObject.visitedDownloadsCount
        viewsVisited.eventLog = managedObject.visitedEventLogCount
        viewsVisited.genreDetail = managedObject.visitedGenreDetailCount
        viewsVisited.genres = managedObject.visitedGenresCount
        viewsVisited.library = managedObject.visitedLibraryCount
        viewsVisited.license = managedObject.visitedLicenseCount
        viewsVisited.playlistDetail = managedObject.visitedPlaylistDetailCount
        viewsVisited.playlists = managedObject.visitedPlaylistsCount
        viewsVisited.playlistSelector = managedObject.visitedPlaylistSelectorCount
        viewsVisited.popupPlayer = managedObject.visitedPopupPlayerCount
        viewsVisited.search = managedObject.visitedSearchCount
        viewsVisited.settings = managedObject.visitedSettingsCount
        viewsVisited.settingsLibrary = managedObject.visitedSettingsLibraryCount
        viewsVisited.settingsPlayer = managedObject.visitedSettingsPlayerCount
        viewsVisited.settingsServer = managedObject.visitedSettingsServerCount
        viewsVisited.settingsSupport = managedObject.visitedSettingsSupportCount
        viewsVisited.songs = managedObject.visitedSongsCount
        overview.viewsVisitedCounts = viewsVisited
        
        return overview
    }
    
}

public struct UserStatisticsOverview: Encodable {
    public var appVersion: String?
    public var creationDate: Date?
    public var appSessionsStartedCount: Int32?
    public var actionsUsedCounts: ActionUsedCounts?
    public var songPlayedConfigCounts: SongPlayedConfigCounts?
    public var viewsVisitedCounts: ViewsVisitedCounts?
}

public struct ActionUsedCounts: Encodable {
    public var airplay: Int32?
    public var alertGoToAlbum: Int32?
    public var alertGoToArtist: Int32?
    public var changePlayerDisplayStyle: Int32?
    public var playerOptions: Int32?
    public var playerSeek: Int32?
}

public struct SongPlayedConfigCounts: Encodable {
    public var playedSongsCount: Int32?
    public var playedSongFromCacheCount: Int32?
    public var playedSongViaStreamCount: Int32?
    public var activeRepeatOffSongsCount: Int32?
    public var activeRepeatAllSongsCount: Int32?
    public var activeRepeatSingleSongsCount: Int32?
    public var activeShuffleOnSongsCount: Int32?
    public var activeShuffleOffSongsCount: Int32?
}

public struct ViewsVisitedCounts: Encodable {
    public var albumDetail: Int32?
    public var albums: Int32?
    public var artistDetail: Int32?
    public var artists: Int32?
    public var downloads: Int32?
    public var eventLog: Int32?
    public var genreDetail: Int32?
    public var genres: Int32?
    public var library: Int32?
    public var license: Int32?
    public var playlistDetail: Int32?
    public var playlists: Int32?
    public var playlistSelector: Int32?
    public var popupPlayer: Int32?
    public var search: Int32?
    public var settings: Int32?
    public var settingsLibrary: Int32?
    public var settingsPlayer: Int32?
    public var settingsServer: Int32?
    public var settingsSupport: Int32?
    public var songs: Int32?
}
