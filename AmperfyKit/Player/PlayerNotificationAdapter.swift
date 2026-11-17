//
//  PlayerNotificationAdapter.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.04.22.
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

import Foundation

// MARK: - PlayerNotificationAdapter

/// Posts the player events and keeps the player in the stored online/offline mode
@MainActor
class PlayerNotificationAdapter {
  let notificationHandler: EventNotificationHandler
  private var player: PlayerFacade
  private let settings: AmperfySettings

  init(
    notificationHandler: EventNotificationHandler,
    player: PlayerFacade,
    settings: AmperfySettings
  ) {
    self.notificationHandler = notificationHandler
    self.player = player
    self.settings = settings
    applyOfflineMode()
    notificationHandler.register(
      self,
      selector: #selector(applyOfflineMode),
      name: .offlineModeChanged,
      object: nil
    )
  }

  /// Offline, the player neither streams, preloads a stream nor autoplays; a song already
  /// streaming plays to its end
  @objc
  private func applyOfflineMode() {
    player.isOfflineMode = settings.user.isOfflineMode
  }
}

// MARK: MusicPlayable

extension PlayerNotificationAdapter: MusicPlayable {
  func didStartPlayingFromBeginning() {}

  func didStartPlaying() {
    notificationHandler.post(name: .playerPlay, object: self, userInfo: nil)
  }

  func didPause() {
    notificationHandler.post(name: .playerPause, object: self, userInfo: nil)
  }

  func didStopPlaying() {
    notificationHandler.post(name: .playerStop, object: self, userInfo: nil)
  }

  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}
}
