//
//  LegacySettings.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

// MARK: - PersistentStorage

extension PersistentStorage {
  final public class LegacySettings: Sendable {
    public var artworkDownloadSetting: ArtworkDownloadSetting {
      get {
        let artworkDownloadSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) as? Int ??
          ArtworkDownloadSetting.defaultValue.rawValue
        return ArtworkDownloadSetting(rawValue: artworkDownloadSettingRaw) ?? ArtworkDownloadSetting
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue
      ) }
    }

    public var artworkDisplayPreference: ArtworkDisplayPreference {
      get {
        let artworkDisplayStyleRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) as? Int ??
          ArtworkDisplayPreference.defaultValue.rawValue
        return ArtworkDisplayPreference(rawValue: artworkDisplayStyleRaw) ??
          ArtworkDisplayPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue
      ) }
    }

    public var screenLockPreventionPreference: ScreenLockPreventionPreference {
      get {
        let screenLockPreventionPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ScreenLockPreventionPreference.rawValue) as? Int ??
          ScreenLockPreventionPreference.defaultValue.rawValue
        return ScreenLockPreventionPreference(rawValue: screenLockPreventionPreferenceRaw) ??
          ScreenLockPreventionPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ScreenLockPreventionPreference.rawValue
      ) }
    }

    public var themePreference: ThemePreference {
      get {
        let themePreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ThemePreference.rawValue) as? Int ??
          ThemePreference.defaultValue.rawValue
        return ThemePreference(rawValue: themePreferenceRaw) ?? ThemePreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ThemePreference.rawValue
      ) }
    }

    public var appearanceMode: UIUserInterfaceStyle {
      get {
        let appearanceModeRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.AppearanceMode.rawValue) as? Int ??
          UIUserInterfaceStyle.unspecified.rawValue
        return UIUserInterfaceStyle(rawValue: appearanceModeRaw) ?? .unspecified
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.AppearanceMode.rawValue
      ) }
    }

    public var streamingMaxBitrateWifiPreference: StreamingMaxBitratePreference {
      get {
        let streamingMaxBitrateWifiPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.StreamingMaxBitrateWifiPreference.rawValue) as? Int ??
          StreamingMaxBitratePreference.defaultValue.rawValue
        return StreamingMaxBitratePreference(rawValue: streamingMaxBitrateWifiPreferenceRaw) ??
          StreamingMaxBitratePreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.StreamingMaxBitrateWifiPreference.rawValue
      ) }
    }

    public var streamingMaxBitrateCellularPreference: StreamingMaxBitratePreference {
      get {
        let streamingMaxBitrateCelluarPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.StreamingMaxBitrateCellularPreference.rawValue) as? Int ??
          StreamingMaxBitratePreference.defaultValue.rawValue
        return StreamingMaxBitratePreference(rawValue: streamingMaxBitrateCelluarPreferenceRaw) ??
          StreamingMaxBitratePreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.StreamingMaxBitrateCellularPreference.rawValue
      ) }
    }

    /// deprecated: use Wifi and Cellular instead
    public var streamingFormatPreference: StreamingFormatPreference {
      get {
        let streamingFormatPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.StreamingFormatPreference.rawValue) as? Int ??
          StreamingFormatPreference.defaultValue.rawValue
        return StreamingFormatPreference(rawValue: streamingFormatPreferenceRaw) ??
          StreamingFormatPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.StreamingFormatPreference.rawValue
      ) }
    }

    public var streamingFormatWifiPreference: StreamingFormatPreference {
      get {
        let streamingFormatPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.StreamingFormatWifiPreference.rawValue) as? Int ??
          StreamingFormatPreference.defaultValue.rawValue
        return StreamingFormatPreference(rawValue: streamingFormatPreferenceRaw) ??
          StreamingFormatPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.StreamingFormatWifiPreference.rawValue
      ) }
    }

    public var streamingFormatCellularPreference: StreamingFormatPreference {
      get {
        let streamingFormatPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.StreamingFormatCellularPreference.rawValue) as? Int ??
          StreamingFormatPreference.defaultValue.rawValue
        return StreamingFormatPreference(rawValue: streamingFormatPreferenceRaw) ??
          StreamingFormatPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.StreamingFormatCellularPreference.rawValue
      ) }
    }

    public var cacheTranscodingFormatPreference: CacheTranscodingFormatPreference {
      get {
        let cacheTranscodingFormatPreferenceRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.CacheTranscodingFormatPreference.rawValue) as? Int ??
          CacheTranscodingFormatPreference.defaultValue.rawValue
        return CacheTranscodingFormatPreference(rawValue: cacheTranscodingFormatPreferenceRaw) ??
          CacheTranscodingFormatPreference.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.CacheTranscodingFormatPreference.rawValue
      ) }
    }

    public var isShowDetailedInfo: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.ShowDetailedInfo.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowDetailedInfo.rawValue) }
    }

    public var isShowSongDuration: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.ShowSongDuration.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowSongDuration.rawValue) }
    }

    public var isShowAlbumDuration: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.ShowAlbumDuration.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowAlbumDuration.rawValue)
      }
    }

    public var isShowArtistDuration: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.ShowArtistDuration.rawValue) as? Bool ?? false
      }
      set {
        UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowArtistDuration.rawValue)
      }
    }

    public var isPlayerShuffleButtonEnabled: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.PlayerShuffleButtonEnabled.rawValue) as? Bool ?? true
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.PlayerShuffleButtonEnabled.rawValue
      ) }
    }

    public var isShowMusicPlayerSkipButtons: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.ShowMusicPlayerSkipButtons.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.ShowMusicPlayerSkipButtons.rawValue
      ) }
    }

    public var isLyricsSmoothScrolling: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsLyricsSmoothScrolling.rawValue) as? Bool ?? true
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsLyricsSmoothScrolling.rawValue
      ) }
    }

    public var cacheLimit: Int {
      get {
        UserDefaults.standard.object(forKey: UserDefaultsKey.CacheLimit.rawValue) as? Int ?? 0
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.CacheLimit.rawValue) }
    }

    public var playerVolume: Float {
      get {
        let volume = UserDefaults.standard
          .object(forKey: UserDefaultsKey.PlayerVolume.rawValue) as? Float ?? 1.0
        return (volume >= 0.0 && volume <= 1.0) ? volume : 1.0
      }
      set {
        guard newValue >= 0.0, newValue <= 1.0 else { return }
        UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.PlayerVolume.rawValue)
      }
    }

    public var playlistsSortSetting: PlaylistSortType {
      get {
        let playlistsSortSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) as? Int ?? PlaylistSortType
          .defaultValue.rawValue
        return PlaylistSortType(rawValue: playlistsSortSettingRaw) ?? PlaylistSortType.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue
      ) }
    }

    public var artistsSortSetting: ArtistElementSortType {
      get {
        let artistsSortSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ArtistsSortSetting.rawValue) as? Int ??
          ArtistElementSortType.defaultValue.rawValue
        return ArtistElementSortType(rawValue: artistsSortSettingRaw) ?? ArtistElementSortType
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ArtistsSortSetting.rawValue
      ) }
    }

    public var albumsSortSetting: AlbumElementSortType {
      get {
        let albumsSortSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.AlbumsSortSetting.rawValue) as? Int ??
          AlbumElementSortType.defaultValue.rawValue
        return AlbumElementSortType(rawValue: albumsSortSettingRaw) ?? AlbumElementSortType
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.AlbumsSortSetting.rawValue
      ) }
    }

    public var songsSortSetting: SongElementSortType {
      get {
        let songsSortSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.SongsSortSetting.rawValue) as? Int ?? SongElementSortType
          .defaultValue.rawValue
        return SongElementSortType(rawValue: songsSortSettingRaw) ?? SongElementSortType
          .defaultValue
      }
      set {
        guard newValue != SongElementSortType.starredDate else {
          UserDefaults.standard.set(
            SongElementSortType.defaultValue.rawValue,
            forKey: UserDefaultsKey.SongsSortSetting.rawValue
          )
          return
        }
        UserDefaults.standard.set(
          newValue.rawValue,
          forKey: UserDefaultsKey.SongsSortSetting.rawValue
        )
      }
    }

    public var favoriteSongSortSetting: SongElementSortType {
      get {
        let favoriteSortSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.FavoriteSongSortSetting.rawValue) as? Int ??
          SongElementSortType.defaultValueForFavorite.rawValue
        return SongElementSortType(rawValue: favoriteSortSettingRaw) ?? SongElementSortType
          .defaultValueForFavorite
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.FavoriteSongSortSetting.rawValue
      ) }
    }

    public var artistsFilterSetting: ArtistCategoryFilter {
      get {
        let artistsFilterSettingRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ArtistsFilterSetting.rawValue) as? Int ??
          ArtistElementSortType.defaultValue.rawValue
        return ArtistCategoryFilter(rawValue: artistsFilterSettingRaw) ?? ArtistCategoryFilter
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.ArtistsFilterSetting.rawValue
      ) }
    }

    public var albumsStyleSetting: AlbumsDisplayStyle {
      get {
        let albumsDisplayStyleRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.AlbumsDisplayStyleSetting.rawValue) as? Int ??
          AlbumsDisplayStyle.defaultValue.rawValue
        return AlbumsDisplayStyle(rawValue: albumsDisplayStyleRaw) ?? AlbumsDisplayStyle
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.AlbumsDisplayStyleSetting.rawValue
      ) }
    }

    @MainActor
    public var albumsGridSizeSetting: Int {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.AlbumsGridSizeSetting.rawValue) as? Int ??
          ((UIDevice.current.userInterfaceIdiom == .pad) ? 4 : 3)
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.AlbumsGridSizeSetting.rawValue
      ) }
    }

    public var swipeActionSettings: SwipeActionSettings {
      get {
        guard let swipeLeadingActionsRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue) as? [Int],
          let swipeTrailingActionsRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue) as? [Int]
        else {
          return SwipeActionSettings.defaultSettings
        }
        let swipeLeadingActions = swipeLeadingActionsRaw
          .compactMap { SwipeActionType(rawValue: $0) }
        let swipeTrailingActions = swipeTrailingActionsRaw
          .compactMap { SwipeActionType(rawValue: $0) }
        return SwipeActionSettings(leading: swipeLeadingActions, trailing: swipeTrailingActions)
      }
      set {
        UserDefaults.standard.set(
          newValue.leading.compactMap { $0.rawValue },
          forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue
        )
        UserDefaults.standard.set(
          newValue.trailing.compactMap { $0.rawValue },
          forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue
        )
      }
    }

    public var libraryDisplaySettings: LibraryDisplaySettings {
      get {
        guard let libraryDisplaySettingsRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue) as? [Int]
        else {
          return LibraryDisplaySettings.defaultSettings
        }
        let libraryDisplaySettings = libraryDisplaySettingsRaw
          .compactMap { LibraryDisplayType(rawValue: $0) }
        return LibraryDisplaySettings(inUse: libraryDisplaySettings)
      }
      set {
        UserDefaults.standard.set(
          newValue.inUse.compactMap { $0.rawValue },
          forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue
        )
      }
    }

    public var podcastsShowSetting: PodcastsShowType {
      get {
        let podcastSortRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) as? Int ?? PodcastsShowType
          .defaultValue.rawValue
        return PodcastsShowType(rawValue: podcastSortRaw) ?? PodcastsShowType.defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.PodcastsShowSetting.rawValue
      ) }
    }

    public var playerDisplayStyle: PlayerDisplayStyle {
      get {
        let playerDisplayStyleRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) as? Int ?? PlayerDisplayStyle
          .defaultValue.rawValue
        return PlayerDisplayStyle(rawValue: playerDisplayStyleRaw) ?? PlayerDisplayStyle
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue
      ) }
    }

    public var isPlayerLyricsDisplayed: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsPlayerLyricsDisplayed.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsPlayerLyricsDisplayed.rawValue
      ) }
    }

    public var isPlayerVisualizerDisplayed: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsPlayerVisualizerDisplayed.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsPlayerVisualizerDisplayed.rawValue
      ) }
    }

    public var isOfflineMode: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsOfflineMode.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsOfflineMode.rawValue) }
    }

    public var isAutoDownloadLatestSongsActive: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue) as? Bool ??
          false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue
      ) }
    }

    public var isAutoDownloadLatestPodcastEpisodesActive: Bool {
      get {
        UserDefaults.standard
          .object(
            forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive
              .rawValue
          ) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive.rawValue
      ) }
    }

    public var isScrobbleStreamedItems: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsScrobbleStreamedItems.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsScrobbleStreamedItems.rawValue
      ) }
    }

    public var isPlaybackStartOnlyOnPlay: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsPlaybackStartOnlyOnPlay.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.IsPlaybackStartOnlyOnPlay.rawValue
      ) }
    }

    public var isOnlineMode: Bool {
      !isOfflineMode
    }

    public var isHapticsEnabled: Bool {
      get { UserDefaults.standard.object(
        forKey: UserDefaultsKey.IsHapticsEnabled.rawValue
      ) as? Bool ?? true }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsHapticsEnabled.rawValue) }
    }

    public var isEqualizerEnabled: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsEqualizerEnabled.rawValue) as? Bool ?? false
      }
      set {
        UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsEqualizerEnabled.rawValue)
      }
    }

    public var activeEqualizerSetting: EqualizerSetting {
      get {
        let configsRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ActiveEqualizerSetting.rawValue) as? String
        guard let configsRaw, let utf8Data = configsRaw.data(using: .utf8) else { return .off }

        let decodedEqualizerSettings = try? JSONDecoder().decode(
          [EqualizerSetting].self,
          from: utf8Data
        )
        return decodedEqualizerSettings?.first ?? EqualizerSetting.off
      }
      set {
        guard let encodedEqualizerSettingsData = try? JSONEncoder().encode([newValue]),
              let encodedEqualizerSettingsString = String(
                data: encodedEqualizerSettingsData,
                encoding: .utf8
              ) else {
          UserDefaults.standard.set(
            "",
            forKey: UserDefaultsKey.ActiveEqualizerSetting.rawValue
          )
          return
        }
        UserDefaults.standard.set(
          encodedEqualizerSettingsString,
          forKey: UserDefaultsKey.ActiveEqualizerSetting.rawValue
        )
      }
    }

    public var equalizerSettings: [EqualizerSetting] {
      get {
        let configsRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.EqualizerSettings.rawValue) as? String
        guard let configsRaw, let utf8Data = configsRaw.data(using: .utf8) else { return [] }

        let decodedEqualizerSettings = try? JSONDecoder().decode(
          [EqualizerSetting].self,
          from: utf8Data
        )
        return decodedEqualizerSettings ?? []
      }
      set {
        guard let encodedEqualizerSettingsData = try? JSONEncoder().encode(newValue),
              let encodedEqualizerSettingsString = String(
                data: encodedEqualizerSettingsData,
                encoding: .utf8
              ) else {
          UserDefaults.standard.set(
            "",
            forKey: UserDefaultsKey.EqualizerSettings.rawValue
          )
          return
        }
        UserDefaults.standard.set(
          encodedEqualizerSettingsString,
          forKey: UserDefaultsKey.EqualizerSettings.rawValue
        )
      }
    }

    public var isReplayGainEnabled: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.IsReplayGainEnabled.rawValue) as? Bool ?? true
      }
      set {
        UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsReplayGainEnabled.rawValue)
      }
    }

    // ordered visible Home Sections
    public var homeSections: [HomeSection] {
      get {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.HomeSections.rawValue),
           let prefs = try? JSONDecoder().decode([HomeSection].self, from: data) {
          return prefs
        }
        return HomeSection.defaultValue
      }
      set {
        if let data = try? JSONEncoder().encode(newValue) {
          UserDefaults.standard.set(data, forKey: UserDefaultsKey.HomeSections.rawValue)
        }
      }
    }

    public var loginCredentials: LoginCredentials? {
      get {
        if let serverUrl = UserDefaults.standard
          .object(forKey: UserDefaultsKey.ServerUrl.rawValue) as? String,
          let username = UserDefaults.standard
          .object(forKey: UserDefaultsKey.Username.rawValue) as? String,
          let passwordHash = UserDefaults.standard
          .object(forKey: UserDefaultsKey.Password.rawValue) as? String,
          let backendApiRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.BackendApi.rawValue) as? Int,
          let backendApi = BackenApiType(rawValue: backendApiRaw) {
          return LoginCredentials(
            serverUrl: serverUrl,
            username: username,
            password: passwordHash,
            backendApi: backendApi
          )
        }
        return nil
      }
      set {
        if let newCredentials = newValue {
          UserDefaults.standard.set(
            newCredentials.serverUrl,
            forKey: UserDefaultsKey.ServerUrl.rawValue
          )
          UserDefaults.standard.set(
            newCredentials.username,
            forKey: UserDefaultsKey.Username.rawValue
          )
          UserDefaults.standard.set(
            newCredentials.password,
            forKey: UserDefaultsKey.Password.rawValue
          )
          UserDefaults.standard.set(
            newCredentials.backendApi.rawValue,
            forKey: UserDefaultsKey.BackendApi.rawValue
          )
        } else {
          UserDefaults.standard.removeObject(forKey: UserDefaultsKey.ServerUrl.rawValue)
          UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Username.rawValue)
          UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Password.rawValue)
          UserDefaults.standard.removeObject(forKey: UserDefaultsKey.BackendApi.rawValue)
        }
      }
    }

    public var alternativeServerURLs: [String] {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.AlternativeServerUrls.rawValue) as? [String] ?? [String]()
      }
      set {
        UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlternativeServerUrls.rawValue)
      }
    }

    public var isLibrarySyncInfoReadByUser: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(
        newValue,
        forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue
      ) }
    }

    public var isLibrarySynced: Bool {
      get {
        UserDefaults.standard
          .object(forKey: UserDefaultsKey.LibraryIsSynced.rawValue) as? Bool ?? false
      }
      set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibraryIsSynced.rawValue) }
    }

    public var initialSyncCompletionStatus: SyncCompletionStatus {
      get {
        let initialSyncCompletionStatusRaw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.InitialSyncCompletionStatus.rawValue) as? Int ??
          SyncCompletionStatus.defaultValue.rawValue
        return SyncCompletionStatus(rawValue: initialSyncCompletionStatusRaw) ??
          SyncCompletionStatus
          .defaultValue
      }
      set { UserDefaults.standard.set(
        newValue.rawValue,
        forKey: UserDefaultsKey.InitialSyncCompletionStatus.rawValue
      ) }
    }

    public var librarySyncVersion: LibrarySyncVersion {
      get {
        if let raw = UserDefaults.standard
          .object(forKey: UserDefaultsKey.LibrarySyncVersion.rawValue) as? Int,
          let version = LibrarySyncVersion(rawValue: raw) {
          return version
        }
        return LibrarySyncVersion.v6
      }
      set {
        UserDefaults.standard.set(
          newValue.rawValue,
          forKey: UserDefaultsKey.LibrarySyncVersion.rawValue
        )
      }
    }
  }

  @MainActor
  public func applyMultiAccountSettingsUpdateIfNeeded() {
    guard let credentials = legacySettings.loginCredentials else { return }
    legacySettings.loginCredentials = nil

    let accountInfo = Account.createInfo(credentials: credentials)
    settings.accounts.login(credentials)
    settings.accounts.updateSetting(accountInfo) { accountSetting in
      accountSetting.artworkDisplayPreference = legacySettings.artworkDisplayPreference
      accountSetting.artworkDownloadSetting = legacySettings.artworkDownloadSetting
      accountSetting.homeSections = legacySettings.homeSections
      accountSetting.initialSyncCompletionStatus = legacySettings.initialSyncCompletionStatus
      accountSetting.isAutoDownloadLatestPodcastEpisodesActive = legacySettings
        .isAutoDownloadLatestPodcastEpisodesActive
      accountSetting.isAutoDownloadLatestSongsActive = legacySettings
        .isAutoDownloadLatestSongsActive
      accountSetting.isScrobbleStreamedItems = legacySettings.isScrobbleStreamedItems
      accountSetting.libraryDisplaySettings = legacySettings.libraryDisplaySettings
      accountSetting.loginCredentials = credentials
      accountSetting.loginCredentials?.alternativeServerURLs = legacySettings.alternativeServerURLs
      accountSetting.themePreference = legacySettings.themePreference
    }

    settings.app.isLibrarySyncInfoReadByUser = legacySettings.isLibrarySyncInfoReadByUser
    settings.app.isLibrarySynced = legacySettings.isLibrarySynced
    settings.app.librarySyncVersion = legacySettings.librarySyncVersion

    settings.user.streamingMaxBitrateWifiPreference = legacySettings
      .streamingMaxBitrateWifiPreference
    settings.user.streamingMaxBitrateCellularPreference = legacySettings
      .streamingMaxBitrateCellularPreference
    settings.user.streamingFormatWifiPreference = legacySettings.streamingFormatWifiPreference
    settings.user.streamingFormatCellularPreference = legacySettings
      .streamingFormatCellularPreference
    settings.user.cacheTranscodingFormatPreference = legacySettings.cacheTranscodingFormatPreference
    settings.user.isShowDetailedInfo = legacySettings.isShowDetailedInfo
    settings.user.isShowSongDuration = legacySettings.isShowSongDuration
    settings.user.isShowAlbumDuration = legacySettings.isShowAlbumDuration
    settings.user.isShowArtistDuration = legacySettings.isShowArtistDuration
    settings.user.isPlayerShuffleButtonEnabled = legacySettings.isPlayerShuffleButtonEnabled
    settings.user.isShowMusicPlayerSkipButtons = legacySettings.isShowMusicPlayerSkipButtons
    settings.user.isLyricsSmoothScrolling = legacySettings.isLyricsSmoothScrolling
    settings.user.cacheLimit = legacySettings.cacheLimit
    settings.user.isPlayerLyricsDisplayed = legacySettings.isPlayerLyricsDisplayed
    settings.user.isPlayerVisualizerDisplayed = legacySettings.isPlayerVisualizerDisplayed
    settings.user.isOfflineMode = legacySettings.isOfflineMode
    settings.user.isPlaybackStartOnlyOnPlay = legacySettings.isPlaybackStartOnlyOnPlay
    settings.user.isHapticsEnabled = legacySettings.isHapticsEnabled
    settings.user.isEqualizerEnabled = legacySettings.isEqualizerEnabled
    settings.user.activeEqualizerSetting = legacySettings.activeEqualizerSetting
    settings.user.equalizerSettings = legacySettings.equalizerSettings
    settings.user.isReplayGainEnabled = legacySettings.isReplayGainEnabled
    settings.user.playerVolume = legacySettings.playerVolume
    settings.user.appearanceMode = legacySettings.appearanceMode
    settings.user.screenLockPreventionPreference = legacySettings.screenLockPreventionPreference
    settings.user.playlistsSortSetting = legacySettings.playlistsSortSetting
    settings.user.artistsSortSetting = legacySettings.artistsSortSetting
    settings.user.albumsSortSetting = legacySettings.albumsSortSetting
    settings.user.swipeActionSettings = legacySettings.swipeActionSettings
    settings.user.songsSortSetting = legacySettings.songsSortSetting
    settings.user.favoriteSongSortSetting = legacySettings.favoriteSongSortSetting
    settings.user.artistsFilterSetting = legacySettings.artistsFilterSetting
    settings.user.albumsStyleSetting = legacySettings.albumsStyleSetting
    settings.user.podcastsShowSetting = legacySettings.podcastsShowSetting
    settings.user.playerDisplayStyle = legacySettings.playerDisplayStyle
    settings.user.albumsGridSizeSetting = legacySettings.albumsGridSizeSetting
  }
}
