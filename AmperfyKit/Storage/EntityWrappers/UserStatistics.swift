//
//  UserStatistics.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation
import UIKit

// MARK: - UserActionUsed

public enum UserActionUsed {
  case
    airplay,
    alertGoToAlbum,
    alertGoToArtist,
    alertGoToPodcast,
    changePlayerDisplayStyle,
    playerOptions,
    playerSeek
}

// MARK: - ViewToVisit

public enum ViewToVisit {
  case
    albumDetail,
    albums,
    artistDetail,
    artists,
    directories,
    downloads,
    eventLog,
    genreDetail,
    genres,
    indexes,
    library,
    license,
    musicFolders,
    playlistDetail,
    playlists,
    playlistSelector,
    podcasts,
    podcastDetail,
    popupPlayer,
    search,
    settings,
    settingsLibrary,
    settingsPlayer,
    settingsPlayerSongTab,
    settingsServer,
    settingsSupport,
    songs,
    radios
}

// MARK: - UserStatistics

public class UserStatistics {
  let managedObject: UserStatisticsMO
  let library: LibraryStorage

  init(managedObject: UserStatisticsMO, library: LibraryStorage) {
    self.managedObject = managedObject
    self.library = library
  }

  var appVersion: String {
    managedObject.appVersion
  }

  var creationDate: Date {
    managedObject.creationDate
  }

  public func sessionStarted() {
    managedObject.appSessionsStartedCount += 1
    library.saveContext()
  }

  public func appStartedViaNotification() {
    managedObject.appStartedViaNotificationCount += 1
    library.saveContext()
  }

  public func localNotificationCreated() {
    managedObject.localNotificationCreationCount += 1
    library.saveContext()
  }

  public func backgroundFetchPerformed(result: UIBackgroundFetchResult) {
    switch result {
    case .newData:
      managedObject.backgroundFetchNewDataCount += 1
    case .noData:
      managedObject.backgroundFetchNoDataCount += 1
    case .failed:
      managedObject.backgroundFetchFailedCount += 1
    @unknown default:
      break
    }
    library.saveContext()
  }

  public func visited(_ visitedView: ViewToVisit) {
    switch visitedView {
    case .albumDetail:
      managedObject.visitedAlbumDetailCount += 1
    case .albums:
      managedObject.visitedAlbumsCount += 1
    case .artistDetail:
      managedObject.visitedArtistDetailCount += 1
    case .artists:
      managedObject.visitedArtistsCount += 1
    case .directories:
      managedObject.visitedDirectoriesCount += 1
    case .downloads:
      managedObject.visitedDownloadsCount += 1
    case .eventLog:
      managedObject.visitedEventLogCount += 1
    case .genreDetail:
      managedObject.visitedGenreDetailCount += 1
    case .indexes:
      managedObject.visitedIndexesCount += 1
    case .genres:
      managedObject.visitedGenresCount += 1
    case .library:
      managedObject.visitedLibraryCount += 1
    case .license:
      managedObject.visitedLicenseCount += 1
    case .musicFolders:
      managedObject.visitedMusicFoldersCount += 1
    case .playlistDetail:
      managedObject.visitedPlaylistDetailCount += 1
    case .playlists:
      managedObject.visitedPlaylistsCount += 1
    case .playlistSelector:
      managedObject.visitedPlaylistSelectorCount += 1
    case .podcasts:
      managedObject.visitedPodcastsCount += 1
    case .podcastDetail:
      managedObject.visitedPodcastDetailCount += 1
    case .popupPlayer:
      managedObject.visitedPopupPlayerCount += 1
    case .search:
      managedObject.visitedSearchCount += 1
    case .settings:
      managedObject.visitedSettingsCount += 1
    case .settingsLibrary:
      managedObject.visitedSettingsLibraryCount += 1
    case .settingsPlayer:
      managedObject.visitedSettingsPlayerCount += 1
    case .settingsPlayerSongTab:
      managedObject.visitedSettingsPlayerSongTabCount += 1
    case .settingsServer:
      managedObject.visitedSettingsServerCount += 1
    case .settingsSupport:
      managedObject.visitedSettingsSupportCount += 1
    case .songs:
      managedObject.visitedSongsCount += 1
    case .radios:
      managedObject.visitedRadiosCount += 1
    }

    library.saveContext()
  }

  func playedItem(repeatMode: RepeatMode, isShuffle: Bool) {
    switch repeatMode {
    case .off:
      managedObject.activeRepeatOffSongsCount += 1
    case .all:
      managedObject.activeRepeatAllSongsCount += 1
    case .single:
      managedObject.activeRepeatSingleSongsCount += 1
    }

    if isShuffle {
      managedObject.activeShuffleOnSongsCount += 1
    } else {
      managedObject.activeShuffleOffSongsCount += 1
    }

    library.saveContext()
  }

  func playedSong(isPlayedFromCache: Bool) {
    if isPlayedFromCache {
      managedObject.playedSongFromCacheCount += 1
    } else {
      managedObject.playedSongViaStreamCount += 1
    }
    managedObject.playedSongsCount += 1
    library.saveContext()
  }

  public func usedAction(_ actionUsed: UserActionUsed) {
    switch actionUsed {
    case .airplay:
      managedObject.usedAirplayCount += 1
    case .alertGoToAlbum:
      managedObject.usedAlertGoToAlbumCount += 1
    case .alertGoToArtist:
      managedObject.usedAlertGoToArtistCount += 1
    case .alertGoToPodcast:
      managedObject.usedAlertGoToPodcastCount += 1
    case .changePlayerDisplayStyle:
      managedObject.usedChangePlayerDisplayStyleCount += 1
    case .playerOptions:
      managedObject.usedPlayerOptionsCount += 1
    case .playerSeek:
      managedObject.usedPlayerSeekCount += 1
    }

    library.saveContext()
  }

  func createLogInfo() -> UserStatisticsOverview {
    var overview = UserStatisticsOverview()
    overview.appVersion = managedObject.appVersion
    overview.creationDate = managedObject.creationDate
    overview.appSessionsStartedCount = managedObject.appSessionsStartedCount
    overview.appStartedViaNotificationCount = managedObject.appStartedViaNotificationCount
    overview.localNotificationCreationCount = managedObject.localNotificationCreationCount
    overview.backgroundFetchFailedCount = managedObject.backgroundFetchFailedCount
    overview.backgroundFetchNewDataCount = managedObject.backgroundFetchNewDataCount
    overview.backgroundFetchNoDataCount = managedObject.backgroundFetchNoDataCount

    var actionUsed = ActionUsedCounts()
    actionUsed.airplay = managedObject.usedAirplayCount
    actionUsed.alertGoToAlbum = managedObject.usedAlertGoToAlbumCount
    actionUsed.alertGoToArtist = managedObject.usedAlertGoToArtistCount
    actionUsed.alertGoToPodcast = managedObject.usedAlertGoToPodcastCount
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
    viewsVisited.directories = managedObject.visitedDirectoriesCount
    viewsVisited.downloads = managedObject.visitedDownloadsCount
    viewsVisited.eventLog = managedObject.visitedEventLogCount
    viewsVisited.genreDetail = managedObject.visitedGenreDetailCount
    viewsVisited.genres = managedObject.visitedGenresCount
    viewsVisited.indexes = managedObject.visitedIndexesCount
    viewsVisited.library = managedObject.visitedLibraryCount
    viewsVisited.license = managedObject.visitedLicenseCount
    viewsVisited.musicFolders = managedObject.visitedMusicFoldersCount
    viewsVisited.playlistDetail = managedObject.visitedPlaylistDetailCount
    viewsVisited.playlists = managedObject.visitedPlaylistsCount
    viewsVisited.playlistSelector = managedObject.visitedPlaylistSelectorCount
    viewsVisited.podcastDetail = managedObject.visitedPodcastDetailCount
    viewsVisited.podcasts = managedObject.visitedPodcastsCount
    viewsVisited.popupPlayer = managedObject.visitedPopupPlayerCount
    viewsVisited.search = managedObject.visitedSearchCount
    viewsVisited.settings = managedObject.visitedSettingsCount
    viewsVisited.settingsLibrary = managedObject.visitedSettingsLibraryCount
    viewsVisited.settingsPlayer = managedObject.visitedSettingsPlayerCount
    viewsVisited.settingsPlayerSongTab = managedObject.visitedSettingsPlayerSongTabCount
    viewsVisited.settingsServer = managedObject.visitedSettingsServerCount
    viewsVisited.settingsSupport = managedObject.visitedSettingsSupportCount
    viewsVisited.songs = managedObject.visitedSongsCount
    viewsVisited.radios = managedObject.visitedRadiosCount
    overview.viewsVisitedCounts = viewsVisited

    return overview
  }
}

// MARK: - UserStatisticsOverview

public struct UserStatisticsOverview: Encodable {
  public var appVersion: String?
  public var creationDate: Date?
  public var appSessionsStartedCount: Int32?
  public var appStartedViaNotificationCount: Int32?
  public var localNotificationCreationCount: Int32?
  public var backgroundFetchFailedCount: Int32?
  public var backgroundFetchNewDataCount: Int32?
  public var backgroundFetchNoDataCount: Int32?
  public var actionsUsedCounts: ActionUsedCounts?
  public var songPlayedConfigCounts: SongPlayedConfigCounts?
  public var viewsVisitedCounts: ViewsVisitedCounts?
}

// MARK: - ActionUsedCounts

public struct ActionUsedCounts: Encodable {
  public var airplay: Int32?
  public var alertGoToAlbum: Int32?
  public var alertGoToArtist: Int32?
  public var alertGoToPodcast: Int32?
  public var changePlayerDisplayStyle: Int32?
  public var playerOptions: Int32?
  public var playerSeek: Int32?
}

// MARK: - SongPlayedConfigCounts

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

// MARK: - ViewsVisitedCounts

public struct ViewsVisitedCounts: Encodable {
  public var albumDetail: Int32?
  public var albums: Int32?
  public var artistDetail: Int32?
  public var artists: Int32?
  public var directories: Int32?
  public var downloads: Int32?
  public var eventLog: Int32?
  public var genreDetail: Int32?
  public var genres: Int32?
  public var indexes: Int32?
  public var library: Int32?
  public var license: Int32?
  public var musicFolders: Int32?
  public var playlistDetail: Int32?
  public var playlists: Int32?
  public var playlistSelector: Int32?
  public var podcastDetail: Int32?
  public var podcasts: Int32?
  public var popupPlayer: Int32?
  public var search: Int32?
  public var settings: Int32?
  public var settingsLibrary: Int32?
  public var settingsPlayer: Int32?
  public var settingsPlayerSongTab: Int32?
  public var settingsServer: Int32?
  public var settingsSupport: Int32?
  public var songs: Int32?
  public var radios: Int32?
}
