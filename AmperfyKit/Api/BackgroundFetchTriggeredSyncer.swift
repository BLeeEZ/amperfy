//
//  BackgroundFetchTriggeredSyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 13.07.21.
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
import os.log
import UIKit

public class BackgroundFetchTriggeredSyncer {
  private let storage: PersistentStorage
  private let account: Account
  private let librarySyncer: LibrarySyncer
  private let notificationManager: LocalNotificationManager
  private let playableDownloadManager: DownloadManageable
  private let log = OSLog(subsystem: "Amperfy", category: "BackgroundFetchTriggeredSyncer")

  init(
    storage: PersistentStorage,
    account: Account,
    librarySyncer: LibrarySyncer,
    notificationManager: LocalNotificationManager,
    playableDownloadManager: DownloadManageable
  ) {
    self.storage = storage
    self.account = account
    self.librarySyncer = librarySyncer
    self.notificationManager = notificationManager
    self.playableDownloadManager = playableDownloadManager
  }

  @MainActor
  public func syncAndNotifyPodcastEpisodes() async throws {
    os_log("Perform podcast episode sync", log: self.log, type: .info)
    let autoDlLibSyncer = AutoDownloadLibrarySyncer(
      storage: storage,
      account: account,
      librarySyncer: librarySyncer,
      playableDownloadManager: playableDownloadManager
    )
    let addedPodcastEpisodes = try await autoDlLibSyncer.syncNewestPodcastEpisodes()
    for episodeToNotify in addedPodcastEpisodes {
      os_log(
        "Podcast: %s, New Episode: %s",
        log: self.log,
        type: .info,
        episodeToNotify.podcast?.name ?? "",
        episodeToNotify.title
      )
      notificationManager.notify(podcastEpisode: episodeToNotify)
    }
  }
}
