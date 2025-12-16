//
//  PlayerDownloadPreparationHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.11.21.
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

import Foundation

// MARK: - PlayerDownloadPreparationHandler

@MainActor
class PlayerDownloadPreparationHandler {
  static let preDownloadCount = 3

  private var playerStatus: PlayerStatusPersistent
  private var queueHandler: PlayQueueHandler
  private var getPlayableDownloaderCB: GetPlayableDownloadManagerCallback

  init(
    playerStatus: PlayerStatusPersistent,
    queueHandler: PlayQueueHandler,
    getPlayableDownloaderCB: @escaping GetPlayableDownloadManagerCallback
  ) {
    self.playerStatus = playerStatus
    self.queueHandler = queueHandler
    self.getPlayableDownloaderCB = getPlayableDownloaderCB
  }

  private func preDownloadNextItems() {
    let upcomingItemsCount = min(
      queueHandler.userQueueCount + queueHandler.nextQueueCount,
      Self.preDownloadCount
    )
    guard upcomingItemsCount > 0 else { return }

    let userQueueRangeEnd = min(queueHandler.userQueueCount, Self.preDownloadCount)
    if userQueueRangeEnd > 0 {
      for i in 0 ... userQueueRangeEnd - 1 {
        let playable = queueHandler.getUserQueueItem(at: i)!
        if !playable.isCached, !playable.isRadio, let accountInfo = playable.account?.info {
          getPlayableDownloaderCB(accountInfo).download(object: playable)
        }
      }
    }
    let nextQueueRangeEnd = min(
      queueHandler.nextQueueCount,
      Self.preDownloadCount - userQueueRangeEnd
    )
    if nextQueueRangeEnd > 0 {
      for i in 0 ... nextQueueRangeEnd - 1 {
        let playable = queueHandler.getNextQueueItem(at: i)!
        if !playable.isCached, !playable.isRadio, let accountInfo = playable.account?.info {
          getPlayableDownloaderCB(accountInfo).download(object: playable)
        }
      }
    }
  }
}

// MARK: MusicPlayable

extension PlayerDownloadPreparationHandler: MusicPlayable {
  func didStartPlayingFromBeginning() {
    if playerStatus.isAutoCachePlayedItems {
      preDownloadNextItems()
    }
  }

  func didStartPlaying() {}
  func didPause() {}
  func didStopPlaying() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}
}
