//
//  LyricsVC.swift
//  Amperfy
//
//  Created by David Klopp on 31.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import Foundation
import MediaPlayer
import UIKit

// MARK: - LyricsVC

class LyricsVC: UIViewController {
  override var title: String? {
    get { "Lyrics" }
    set {}
  }

  var player: PlayerFacade {
    appDelegate.player
  }

  var lyricsView: LyricsView?

  override func viewDidLoad() {
    super.viewDidLoad()

    let lyricsView = LyricsView()
    lyricsView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(lyricsView)

    NSLayoutConstraint.activate([
      lyricsView.topAnchor.constraint(equalTo: view.topAnchor),
      lyricsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      lyricsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      lyricsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    self.lyricsView = lyricsView

    player.addNotifier(notifier: self)
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    refreshLyrics()
  }

  private func fetchSongInfoAndUpdateLyrics() {
    guard appDelegate.storage.settings.user.isOnlineMode,
          let song = player.currentlyPlaying?.asSong,
          let account = song.account
    else { return }

    Task { @MainActor in do {
      try await self.appDelegate.getMeta(account.info).librarySyncer
        .sync(song: song)
      self.refreshLyrics()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Song Info", error: error)
    }}
  }

  private func showLyrics(structuredLyrics: StructuredLyrics) {
    lyricsView?.display(
      lyrics: structuredLyrics,
      scrollAnimation: appDelegate.storage.settings.user.isLyricsSmoothScrolling
    )
  }

  private func showLyricsAreNotAvailable() {
    var notAvailableLyrics = StructuredLyrics()
    notAvailableLyrics.synced = false
    var line = LyricsLine()
    line.value = "No Lyrics"
    notAvailableLyrics.line.append(line)
    showLyrics(structuredLyrics: notAvailableLyrics)
    lyricsView?.highlightAllLyrics()
  }

  func refreshLyrics() {
    guard let playable = player.currentlyPlaying,
          let song = playable.asSong,
          let account = song.account,
          let lyricsRelFilePath = song.lyricsRelFilePath else {
      showLyricsAreNotAvailable()
      return
    }

    Task { @MainActor in do {
      let lyricsList = try await appDelegate.getMeta(account.info).librarySyncer
        .parseLyrics(relFilePath: lyricsRelFilePath)
      if song == self.player.currentlyPlaying?.asSong,
         let structuredLyrics = lyricsList.getFirstSyncedLyricsOrUnsyncedAsDefault() {
        self.showLyrics(structuredLyrics: structuredLyrics)
      } else {
        self.showLyricsAreNotAvailable()
      }
    } catch {
      self.showLyricsAreNotAvailable()
    }}
  }

  func refreshLyricsTime(time: CMTime) {
    lyricsView?.scroll(toTime: time)
  }
}

// MARK: MusicPlayable

extension LyricsVC: MusicPlayable {
  func didStartPlayingFromBeginning() {
    fetchSongInfoAndUpdateLyrics()
  }

  func didStartPlaying() {
    refreshLyrics()
  }

  func didLyricsTimeChange(time: CMTime) {
    refreshLyricsTime(time: time)
  }

  func didPause() {}
  func didStopPlaying() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}
  func didShuffleChange() {}
  func didRepeatChange() {}
  func didPlaybackRateChange() {}
}
