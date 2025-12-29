//
//  Settings.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.12.25.
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

import UIKit

// MARK: - AppSettings

public struct AppSettings: Sendable, Codable {
  private var _isLibrarySyncInfoReadByUser: Bool = false
  public var isLibrarySyncInfoReadByUser: Bool {
    get { _isLibrarySyncInfoReadByUser }
    set { _isLibrarySyncInfoReadByUser = newValue }
  }

  private var _isLibrarySynced: Bool = false
  public var isLibrarySynced: Bool {
    get { _isLibrarySynced }
    set { _isLibrarySynced = newValue }
  }

  private var _librarySyncVersion: LibrarySyncVersion = .v6
  public var librarySyncVersion: LibrarySyncVersion {
    get { _librarySyncVersion }
    set { _librarySyncVersion = newValue }
  }
}

// MARK: - UserSettings

public struct UserSettings: Sendable, Codable {
  private var _streamingMaxBitrateWifiPreference: StreamingMaxBitratePreference = .defaultValue
  public var streamingMaxBitrateWifiPreference: StreamingMaxBitratePreference {
    get { _streamingMaxBitrateWifiPreference }
    set { _streamingMaxBitrateWifiPreference = newValue }
  }

  private var _streamingMaxBitrateCellularPreference: StreamingMaxBitratePreference = .defaultValue
  public var streamingMaxBitrateCellularPreference: StreamingMaxBitratePreference {
    get { _streamingMaxBitrateCellularPreference }
    set { _streamingMaxBitrateCellularPreference = newValue }
  }

  private var _streamingFormatWifiPreference: StreamingFormatPreference = .defaultValue
  public var streamingFormatWifiPreference: StreamingFormatPreference {
    get { _streamingFormatWifiPreference }
    set { _streamingFormatWifiPreference = newValue }
  }

  private var _streamingFormatCellularPreference: StreamingFormatPreference = .defaultValue
  public var streamingFormatCellularPreference: StreamingFormatPreference {
    get { _streamingFormatCellularPreference }
    set { _streamingFormatCellularPreference = newValue }
  }

  private var _cacheTranscodingFormatPreference: CacheTranscodingFormatPreference = .defaultValue
  public var cacheTranscodingFormatPreference: CacheTranscodingFormatPreference {
    get { _cacheTranscodingFormatPreference }
    set { _cacheTranscodingFormatPreference = newValue }
  }

  private var _isShowDetailedInfo: Bool = false
  public var isShowDetailedInfo: Bool {
    get { _isShowDetailedInfo }
    set { _isShowDetailedInfo = newValue }
  }

  private var _isShowSongDuration: Bool = false
  public var isShowSongDuration: Bool {
    get { _isShowSongDuration }
    set { _isShowSongDuration = newValue }
  }

  private var _isShowAlbumDuration: Bool = false
  public var isShowAlbumDuration: Bool {
    get { _isShowAlbumDuration }
    set { _isShowAlbumDuration = newValue }
  }

  private var _isShowArtistDuration: Bool = false
  public var isShowArtistDuration: Bool {
    get { _isShowArtistDuration }
    set { _isShowArtistDuration = newValue }
  }

  private var _isPlayerShuffleButtonEnabled: Bool = true
  public var isPlayerShuffleButtonEnabled: Bool {
    get { _isPlayerShuffleButtonEnabled }
    set { _isPlayerShuffleButtonEnabled = newValue }
  }

  private var _isShowMusicPlayerSkipButtons: Bool = false
  public var isShowMusicPlayerSkipButtons: Bool {
    get { _isShowMusicPlayerSkipButtons }
    set { _isShowMusicPlayerSkipButtons = newValue }
  }

  private var _isLyricsSmoothScrolling: Bool = true
  public var isLyricsSmoothScrolling: Bool {
    get { _isLyricsSmoothScrolling }
    set { _isLyricsSmoothScrolling = newValue }
  }

  // limit in byte
  private var _cacheLimit: Int = 0
  public var cacheLimit: Int {
    get { _cacheLimit }
    set { _cacheLimit = newValue }
  }

  private var _isPlayerLyricsDisplayed: Bool = false
  public var isPlayerLyricsDisplayed: Bool {
    get { _isPlayerLyricsDisplayed }
    set { _isPlayerLyricsDisplayed = newValue }
  }

  private var _isPlayerVisualizerDisplayed: Bool = false
  public var isPlayerVisualizerDisplayed: Bool {
    get { _isPlayerVisualizerDisplayed }
    set { _isPlayerVisualizerDisplayed = newValue }
  }

  private var _selectedVisualizerType: VisualizerType = .defaultValue
  public var selectedVisualizerType: VisualizerType {
    get { _selectedVisualizerType }
    set { _selectedVisualizerType = newValue }
  }

  private var _isOfflineMode: Bool = false
  public var isOfflineMode: Bool {
    get { _isOfflineMode }
    set { _isOfflineMode = newValue }
  }

  public var isOnlineMode: Bool {
    !_isOfflineMode
  }

  private var _isPlaybackStartOnlyOnPlay: Bool = false
  public var isPlaybackStartOnlyOnPlay: Bool {
    get { _isPlaybackStartOnlyOnPlay }
    set { _isPlaybackStartOnlyOnPlay = newValue }
  }

  private var _isPlayerSongPlaybackResumeEnabled: Bool = false
  public var isPlayerSongPlaybackResumeEnabled: Bool {
    get { _isPlayerSongPlaybackResumeEnabled }
    set { _isPlayerSongPlaybackResumeEnabled = newValue }
  }

  private var _isHapticsEnabled: Bool = true
  public var isHapticsEnabled: Bool {
    get { _isHapticsEnabled }
    set { _isHapticsEnabled = newValue }
  }

  private var _isEqualizerEnabled: Bool = false
  public var isEqualizerEnabled: Bool {
    get { _isEqualizerEnabled }
    set { _isEqualizerEnabled = newValue }
  }

  private var _activeEqualizerSetting: EqualizerSetting = .off
  public var activeEqualizerSetting: EqualizerSetting {
    get { _activeEqualizerSetting }
    set { _activeEqualizerSetting = newValue }
  }

  private var _equalizerSettings: [EqualizerSetting] = []
  public var equalizerSettings: [EqualizerSetting] {
    get { _equalizerSettings }
    set { _equalizerSettings = newValue }
  }

  private var _isReplayGainEnabled: Bool = true
  public var isReplayGainEnabled: Bool {
    get { _isReplayGainEnabled }
    set { _isReplayGainEnabled = newValue }
  }

  private var _playerVolume: Float = 1.0
  public var playerVolume: Float {
    get {
      (_playerVolume >= 0.0 && _playerVolume <= 1.0) ? _playerVolume : 1.0
    }
    set {
      guard newValue >= 0.0, newValue <= 1.0 else { return }
      _playerVolume = newValue
    }
  }

  private var _appearanceMode: UIUserInterfaceStyle = .unspecified
  public var appearanceMode: UIUserInterfaceStyle {
    get { _appearanceMode }
    set { _appearanceMode = newValue }
  }

  private var _screenLockPreventionPreference: ScreenLockPreventionPreference = .defaultValue
  public var screenLockPreventionPreference: ScreenLockPreventionPreference {
    get { _screenLockPreventionPreference }
    set { _screenLockPreventionPreference = newValue }
  }

  private var _playlistsSortSetting: PlaylistSortType = .defaultValue
  public var playlistsSortSetting: PlaylistSortType {
    get { _playlistsSortSetting }
    set { _playlistsSortSetting = newValue }
  }

  private var _artistsSortSetting: ArtistElementSortType = .defaultValue
  public var artistsSortSetting: ArtistElementSortType {
    get { _artistsSortSetting }
    set { _artistsSortSetting = newValue }
  }

  private var _albumsSortSetting: AlbumElementSortType = .defaultValue
  public var albumsSortSetting: AlbumElementSortType {
    get { _albumsSortSetting }
    set { _albumsSortSetting = newValue }
  }

  private var _swipeActionSettings: SwipeActionSettings = .defaultSettings
  public var swipeActionSettings: SwipeActionSettings {
    get { _swipeActionSettings }
    set { _swipeActionSettings = newValue }
  }

  private var _songsSortSetting: SongElementSortType = .defaultValue
  public var songsSortSetting: SongElementSortType {
    get { _songsSortSetting }
    set {
      if newValue == SongElementSortType.starredDate {
        _songsSortSetting = .defaultValue
      } else {
        _songsSortSetting = newValue
      }
    }
  }

  private var _favoriteSongSortSetting: SongElementSortType = .defaultValueForFavorite
  public var favoriteSongSortSetting: SongElementSortType {
    get { _favoriteSongSortSetting }
    set { _favoriteSongSortSetting = newValue }
  }

  private var _artistsFilterSetting: ArtistCategoryFilter = .defaultValue
  public var artistsFilterSetting: ArtistCategoryFilter {
    get { _artistsFilterSetting }
    set { _artistsFilterSetting = newValue }
  }

  private var _albumsStyleSetting: AlbumsDisplayStyle = .defaultValue
  public var albumsStyleSetting: AlbumsDisplayStyle {
    get { _albumsStyleSetting }
    set { _albumsStyleSetting = newValue }
  }

  private var _podcastsShowSetting: PodcastsShowType = .defaultValue
  public var podcastsShowSetting: PodcastsShowType {
    get { _podcastsShowSetting }
    set { _podcastsShowSetting = newValue }
  }

  private var _playerDisplayStyle: PlayerDisplayStyle = .defaultValue
  public var playerDisplayStyle: PlayerDisplayStyle {
    get { _playerDisplayStyle }
    set { _playerDisplayStyle = newValue }
  }

  private var _albumsGridSizeSetting: Int?
  @MainActor
  public var albumsGridSizeSetting: Int {
    get {
      _albumsGridSizeSetting ?? ((UIDevice.current.userInterfaceIdiom == .pad) ? 4 : 3)
    }
    set { _albumsGridSizeSetting = newValue }
  }
}

// MARK: - AccountSetting

public struct AccountSetting: Sendable, Codable {
  private var _artworkDisplayPreference: ArtworkDisplayPreference = .defaultValue
  public var artworkDisplayPreference: ArtworkDisplayPreference {
    get { _artworkDisplayPreference }
    set { _artworkDisplayPreference = newValue }
  }

  private var _artworkDownloadSetting: ArtworkDownloadSetting = .defaultValue
  public var artworkDownloadSetting: ArtworkDownloadSetting {
    get { _artworkDownloadSetting }
    set { _artworkDownloadSetting = newValue }
  }

  // ordered visible Home Sections
  private var _homeSections: [HomeSection] = HomeSection.defaultValue
  public var homeSections: [HomeSection] {
    get { _homeSections }
    set { _homeSections = newValue }
  }

  private var _initialSyncCompletionStatus: SyncCompletionStatus = .defaultValue
  public var initialSyncCompletionStatus: SyncCompletionStatus {
    get { _initialSyncCompletionStatus }
    set { _initialSyncCompletionStatus = newValue }
  }

  private var _isAutoDownloadLatestPodcastEpisodesActive: Bool = false
  public var isAutoDownloadLatestPodcastEpisodesActive: Bool {
    get { _isAutoDownloadLatestPodcastEpisodesActive }
    set { _isAutoDownloadLatestPodcastEpisodesActive = newValue }
  }

  private var _isAutoDownloadLatestSongsActive: Bool = false
  public var isAutoDownloadLatestSongsActive: Bool {
    get { _isAutoDownloadLatestSongsActive }
    set { _isAutoDownloadLatestSongsActive = newValue }
  }

  private var _isScrobbleStreamedItems: Bool = false
  public var isScrobbleStreamedItems: Bool {
    get { _isScrobbleStreamedItems }
    set { _isScrobbleStreamedItems = newValue }
  }

  private var _libraryDisplaySettings: LibraryDisplaySettings = .defaultSettings
  public var libraryDisplaySettings: LibraryDisplaySettings {
    get { _libraryDisplaySettings }
    set { _libraryDisplaySettings = newValue }
  }

  private var _loginCredentials: LoginCredentials? = nil
  public var loginCredentials: LoginCredentials? {
    get { _loginCredentials }
    set { _loginCredentials = newValue }
  }

  private var _themePreference: ThemePreference = .defaultValue
  public var themePreference: ThemePreference {
    get { _themePreference }
    set { _themePreference = newValue }
  }
}

// MARK: - ReadOnlyAccountSetting

public struct ReadOnlyAccountSetting {
  public let read: AccountSetting
}

// MARK: - AccountSettings

public struct AccountSettings: Sendable, Codable {
  fileprivate var _accounts: [AccountInfo: AccountSetting] = [:]
  fileprivate var _activeAccount: AccountInfo?

  public mutating func switchActiveAccount(_ accountInfo: AccountInfo) {
    _activeAccount = accountInfo
  }

  public mutating func login(_ loginCredentials: LoginCredentials) {
    let accountInfo = Account.createInfo(credentials: loginCredentials)
    let newTheme = themeColorForNextNewAccount
    updateSetting(accountInfo) { accountSettings in
      accountSettings.loginCredentials = loginCredentials
      accountSettings.themePreference = newTheme
    }
    _activeAccount = accountInfo
  }

  public func getSetting(_ accountInfo: AccountInfo?) -> ReadOnlyAccountSetting {
    // Settings Priority:
    // 1.: provided account settings (if not nil)
    // 2.: active account settings (if logged in)
    // 3.: default settings
    if let info = accountInfo ?? _activeAccount, let accountSettings = _accounts[info] {
      return ReadOnlyAccountSetting(read: accountSettings)
    } else {
      return ReadOnlyAccountSetting(read: AccountSetting())
    }
  }

  public mutating func logout(_ accountInfo: AccountInfo) {
    _accounts[accountInfo] = nil
    if _activeAccount == accountInfo {
      _activeAccount = _accounts.first?.key
    }
  }

  public mutating func updateSetting(
    _ accountInfo: AccountInfo,
    _ update: (inout AccountSetting) -> ()
  ) {
    var setting = _accounts[accountInfo] ?? AccountSetting()
    update(&setting)
    _accounts[accountInfo] = setting
  }

  public var active: AccountInfo? {
    _activeAccount
  }

  public var activeSetting: ReadOnlyAccountSetting {
    guard let _activeAccount else { return ReadOnlyAccountSetting(read: AccountSetting()) }
    return ReadOnlyAccountSetting(read: _accounts[_activeAccount] ?? AccountSetting())
  }

  public var availableApiTypes: Set<ServerApiType> {
    Set(_accounts.compactMap { $0.value.loginCredentials?.backendApi.asServerApiType })
  }

  public var allAccounts: [AccountInfo] {
    _accounts.compactMap { $0.key }.sorted(by: {
      guard let cred0 = getSetting($0).read.loginCredentials,
            let cred1 = getSetting($1).read.loginCredentials
      else { return false }

      if cred0.displayServerUrl != cred1.displayServerUrl {
        return cred0.displayServerUrl < cred1.displayServerUrl
      } else {
        return cred0.username < cred1.username
      }
    })
  }

  private var themeColorForNextNewAccount: ThemePreference {
    var theme = ThemePreference.blue
    let usedThemes = Set(_accounts.compactMap { $0.value.themePreference })
    let allThemes = Set(ThemePreference.allCases)
    let availableThemes = allThemes.subtracting(usedThemes)
    if let firstAvailable = availableThemes.sorted(by: { $0.rawValue < $1.rawValue }).first {
      theme = firstAvailable
    } else if let activeAccount = _activeAccount {
      let activeTheme = getSetting(activeAccount).read.themePreference
      theme = allThemes.subtracting(Set([activeTheme])).sorted(by: { $0.rawValue < $1.rawValue })
        .first ?? .blue
    }
    return theme
  }
}

// MARK: - AmperfySettings

public struct AmperfySettings: Sendable, Codable {
  // MARK: - Persistence

  private static let decoder: JSONDecoder = .init()
  private static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = []
    return e
  }()

  private var _appSettings: AppSettings = .init()
  public var app: AppSettings {
    get {
      guard let data = UserDefaults.standard
        .data(forKey: PersistentStorage.UserDefaultsKey.SettingsApp.rawValue)
      else { return _appSettings }
      do {
        return try Self.decoder.decode(AppSettings.self, from: data)
      } catch {
        return _appSettings
      }
    }
    set {
      _appSettings = newValue
      do {
        let data = try Self.encoder.encode(_appSettings)
        UserDefaults.standard.set(
          data,
          forKey: PersistentStorage.UserDefaultsKey.SettingsApp.rawValue
        )
      } catch {}
    }
  }

  private var _userSettings: UserSettings = .init()
  public var user: UserSettings {
    get {
      guard let data = UserDefaults.standard
        .data(forKey: PersistentStorage.UserDefaultsKey.SettingsUser.rawValue)
      else { return _userSettings }
      do {
        return try Self.decoder.decode(UserSettings.self, from: data)
      } catch {
        return _userSettings
      }
    }
    set {
      _userSettings = newValue
      do {
        let data = try Self.encoder.encode(_userSettings)
        UserDefaults.standard.set(
          data,
          forKey: PersistentStorage.UserDefaultsKey.SettingsUser.rawValue
        )
      } catch {}
    }
  }

  private var _accountSettings: AccountSettings = .init()
  public var accounts: AccountSettings {
    get {
      guard let data = UserDefaults.standard
        .data(forKey: PersistentStorage.UserDefaultsKey.SettingsAccount.rawValue)
      else { return _accountSettings }
      do {
        return try Self.decoder.decode(AccountSettings.self, from: data)
      } catch {
        return _accountSettings
      }
    }
    set {
      _accountSettings = newValue
      do {
        let data = try Self.encoder.encode(_accountSettings)
        UserDefaults.standard.set(
          data,
          forKey: PersistentStorage.UserDefaultsKey.SettingsAccount.rawValue
        )
      } catch {}
    }
  }
}
