//
//  ObservableSettings.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 20.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import SwiftUI

final class Settings: ObservableObject {
  @Published
  var isOfflineMode = false
  @Published
  var isShowDetailedInfo = false
  @Published
  var isShowSongDuration = false
  @Published
  var isShowAlbumDuration = false
  @Published
  var isShowArtistDuration = false
  @Published
  var isPlayerShuffleButtonEnabled = true
  @Published
  var screenLockPreventionPreference: ScreenLockPreventionPreference = .defaultValue
  @Published
  var streamingMaxBitrateWifiPreference: StreamingMaxBitratePreference = .defaultValue
  @Published
  var streamingMaxBitrateCellularPreference: StreamingMaxBitratePreference =
    .defaultValue
  @Published
  var streamingFormatCellularPreference: StreamingFormatPreference = .defaultValue
  @Published
  var streamingFormatWifiPreference: StreamingFormatPreference = .defaultValue
  @Published
  var cacheTranscodingFormatPreference: CacheTranscodingFormatPreference = .defaultValue
  @Published
  var isAutoCacheLatestSongs = false
  @Published
  var isAutoCacheLatestPodcastEpisodes = false
  @Published
  var isPlayerAutoCachePlayedItems = false
  @Published
  var isScrobbleStreamedItems = false
  @Published
  var isPlaybackStartOnlyOnPlay = false
  @Published
  var isPlayerSongPlaybackResumeEnabled = false
  @Published
  var isShowMusicPlayerSkipButtons = false
  @Published
  var isLyricsSmoothScrolling = true
  @Published
  var swipeActionSettings = SwipeActionSettings(leading: [], trailing: [])
  @Published
  var cacheSizeLimit: Int = 0 // limit in byte
  @Published
  var isHapticsEnabled = true

  @Published
  var activeAccountInfo: AccountInfo?
  @Published
  var themePreference: ThemePreference = .defaultValue
  @Published
  var appearanceMode: UIUserInterfaceStyle = .unspecified

  @Published
  var isEqualizerEnabled = false
  @Published
  var activeEqualizerSetting: EqualizerSetting = .off
  @Published
  var equalizerSettings: [EqualizerSetting] = []

  @Published
  var isReplayGainEnabled = true
}
