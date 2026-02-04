//
//  AudioPlayer.swift
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

import AVFoundation
import Foundation
import MediaPlayer
import os.log

// MARK: - WeakMusicPlayable

final class WeakMusicPlayable {
  weak var value: MusicPlayable?
  init(_ value: MusicPlayable) {
    self.value = value
  }
}

// MARK: - AudioPlayer

@MainActor
public class AudioPlayer: NSObject, BackendAudioPlayerNotifiable {
  public static let replayInsteadPlayPreviousTimeInSec = 5.0
  static let progressTimeStartThreshold: Double = 15.0
  static let progressTimeEndThreshold: Double = 15.0

  var currentlyPlaying: AbstractPlayable? {
    queueHandler.currentlyPlaying
  }

  var currentMusicItem: AbstractPlayable? {
    queueHandler.currentMusicItem
  }

  var currentPodcastItem: AbstractPlayable? {
    queueHandler.currentPodcastItem
  }

  var isShouldPauseAfterFinishedPlaying = false

  private var playerStatus: PlayerStatusPersistent
  private var queueHandler: PlayQueueHandler
  private let backendAudioPlayer: BackendAudioPlayer
  private let settings: AmperfySettings
  private let userStatistics: UserStatistics
  private var notifierList: [WeakMusicPlayable] = []

  init(
    coreData: PlayerStatusPersistent,
    queueHandler: PlayQueueHandler,
    backendAudioPlayer: BackendAudioPlayer,
    settings: AmperfySettings,
    userStatistics: UserStatistics
  ) {
    self.playerStatus = coreData
    self.queueHandler = queueHandler
    self.backendAudioPlayer = backendAudioPlayer
    self.backendAudioPlayer.isAutoCachePlayedItems = coreData.isAutoCachePlayedItems
    self.settings = settings
    self.userStatistics = userStatistics
    super.init()
    self.backendAudioPlayer.responder = self
    self.backendAudioPlayer.nextPlayablePreloadCB = { () in
      guard !self.isShouldPauseAfterFinishedPlaying else { return nil }
      guard self.playerStatus.repeatMode != .single else { return nil }
      guard let nextPlayerIndex = self.nextPlayerIndex else { return nil }
      return self.queueHandler.getPlayable(at: nextPlayerIndex)
    }
  }

  private func shouldCurrentItemReplayedInsteadOfPrevious() -> Bool {
    if let currentlyPlaying = currentlyPlaying,
       currentlyPlaying.isRadio {
      return false
    }
    if !backendAudioPlayer.canBeContinued {
      return false
    }
    return backendAudioPlayer.elapsedTime >= Self.replayInsteadPlayPreviousTimeInSec
  }

  private func replayCurrentItem(autoStartPlayback: Bool? = nil) {
    os_log(.debug, "Replay")
    if let currentPlayable = currentlyPlaying {
      // Clear play progress since we're replaying from the beginning
      currentPlayable.playProgress = 0
      insertIntoPlayer(playable: currentPlayable, autoStartPlayback: autoStartPlayback)
    }
    notifyItemStartedPlayingFromBeginning()
  }

  private func insertIntoPlayer(playable: AbstractPlayable, autoStartPlayback: Bool? = nil) {
    userStatistics.playedItem(
      repeatMode: playerStatus.repeatMode,
      isShuffle: playerStatus.isShuffle
    )
    // Only update lastTimePlayed locally; playCount is managed by the server
    playable.lastTimePlayed = Date()
    // Use provided autoStartPlayback, or fall back to user setting
    let shouldAutoStart = autoStartPlayback ?? !settings.user.isPlaybackStartOnlyOnPlay
    backendAudioPlayer.requestToPlay(
      playable: playable,
      playbackRate: playerStatus.playbackRate,
      autoStartPlayback: shouldAutoStart
    )
  }

  // BackendAudioPlayerNotifiable
  func notifyItemPreparationFinished() {
    notifyItemStartedPlayingFromBeginning()
    notifyItemStartedPlaying()
  }

  // BackendAudioPlayerNotifiable
  func didItemFinishedPlaying() {
    if isShouldPauseAfterFinishedPlaying {
      isShouldPauseAfterFinishedPlaying = false
      pause()
    } else if playerStatus
      .repeatMode == .single ||
      (
        // repeat mode all and only one song is in player -> repeat
        playerStatus.repeatMode == .all && queueHandler.prevQueueCount == 0 && queueHandler
          .userQueueCount == 0 && queueHandler
          .nextQueueCount == 0
      ) {
      replayCurrentItem()
    } else if !settings.user.isPlaybackStartOnlyOnPlay {
      playNext()
    }
  }

  func play() {
    if !backendAudioPlayer.canBeContinued {
      if let currentPlayable = currentlyPlaying {
        insertIntoPlayer(playable: currentPlayable)
      }
    } else {
      backendAudioPlayer.continuePlay()
      notifyItemStartedPlaying()
    }
  }

  public func play(context: PlayContext) {
    guard let activePlayable = context.getActivePlayable() else { return }
    let previouslyPlaying = currentlyPlaying
    let topUserQueueItem = queueHandler.getUserQueueItem(at: 0)
    let wasUserQueuePlaying = queueHandler.isUserQueuePlaying
    queueHandler.clearActiveQueue()
    queueHandler.appendActiveQueue(playables: context.playables)
    if context.type == .music {
      queueHandler.setContextName(context.name)
    }

    if queueHandler.isUserQueuePlaying {
      play(playerIndex: PlayerIndex(queueType: .next, index: context.index))
      if !wasUserQueuePlaying, let topUserQueueItem = topUserQueueItem {
        queueHandler.insertUserQueue(playables: [topUserQueueItem])
      }
    } else if context.index == 0 {
      // Clear play progress when switching to a different song
      // If previouslyPlaying is nil (app restart), don't clear - allows resume
      if let previous = previouslyPlaying, previous != activePlayable {
        previous.playProgress = 0
        // Also clear new song's progress to remove any stale stored progress
        if activePlayable.isSong {
          activePlayable.playProgress = 0
        }
      }
      insertIntoPlayer(playable: activePlayable)
    } else {
      play(playerIndex: PlayerIndex(queueType: .next, index: context.index - 1))
    }
  }

  func play(playerIndex: PlayerIndex, autoStartPlayback: Bool? = nil) {
    let previouslyPlaying = currentlyPlaying
    
    guard let playable = queueHandler.markAndGetPlayableAsPlaying(at: playerIndex) else {
      stop()
      return
    }
    
    // Clear play progress when switching to a different song
    // If previouslyPlaying is nil (app restart), don't clear - allows resume
    if let previous = previouslyPlaying, previous != playable {
      previous.playProgress = 0
      // Also clear new song's progress to remove any stale stored progress
      if playable.isSong {
        playable.playProgress = 0
      }
    }
    
    insertIntoPlayer(playable: playable, autoStartPlayback: autoStartPlayback)
  }

  func playPreviousOrReplay() {
    // Preserve the current play/pause state when switching tracks
    let wasPlaying = backendAudioPlayer.isPlaying
    if shouldCurrentItemReplayedInsteadOfPrevious() {
      replayCurrentItem(autoStartPlayback: wasPlaying)
    } else {
      playPrevious()
    }
  }

  // BackendAudioPlayerNotifiable
  func playPrevious() {
    // Preserve the current play/pause state when switching tracks
    let wasPlaying = backendAudioPlayer.isPlaying
    if queueHandler.prevQueueCount > 0 {
      play(
        playerIndex: PlayerIndex(queueType: .prev, index: queueHandler.prevQueueCount - 1),
        autoStartPlayback: wasPlaying
      )
    } else if playerStatus.repeatMode == .all, queueHandler.nextQueueCount > 0 {
      play(
        playerIndex: PlayerIndex(queueType: .next, index: queueHandler.nextQueueCount - 1),
        autoStartPlayback: wasPlaying
      )
    } else {
      replayCurrentItem(autoStartPlayback: wasPlaying)
    }
  }

  // BackendAudioPlayerNotifiable
  func playNext() {
    // Preserve the current play/pause state when switching tracks
    let wasPlaying = backendAudioPlayer.isPlaying
    if let nextPlayerIndex = nextPlayerIndex {
      play(playerIndex: nextPlayerIndex, autoStartPlayback: wasPlaying)
    } else {
      stop()
    }
  }

  private var nextPlayerIndex: PlayerIndex? {
    if queueHandler.userQueueCount > 0 {
      return PlayerIndex(queueType: .user, index: 0)
    } else if queueHandler.nextQueueCount > 0 {
      return PlayerIndex(queueType: .next, index: 0)
    } else if playerStatus.repeatMode == .all, queueHandler.prevQueueCount > 0 {
      return PlayerIndex(queueType: .prev, index: 0)
    } else {
      return nil
    }
  }

  func pause() {
    if let currentlyPlaying = currentlyPlaying,
       currentlyPlaying.isRadio {
      stopButRemainIndex()
    } else {
      backendAudioPlayer.pause()
      notifyItemPaused()
    }
  }

  // BackendAudioPlayerNotifiable
  func stop() {
    backendAudioPlayer.stop()
    playerStatus.stop()
    notifyPlayerStopped()
  }

  func stopButRemainIndex() {
    backendAudioPlayer.stop()
    notifyPlayerStopped()
  }

  func togglePlayPause() {
    if backendAudioPlayer.isPlaying {
      pause()
    } else {
      play()
    }
  }

  private func seekToLastStoppedPlayTime() {
    if let playable = currentlyPlaying,
       playable.playProgress > 0,
       playable
       .isPodcastEpisode ||
       (
         (playable.isSong || backendAudioPlayer.isErrorOccurred) && settings.user
           .isPlayerSongPlaybackResumeEnabled
       ) {
      backendAudioPlayer.seek(toSecond: Double(playable.playProgress))
    }
  }

  private var lastPlayInfoSave: Date = .distantPast
  private let playInfoSaveInterval: TimeInterval = 5.0  // Save play progress every 5 seconds instead of every second
  
  // BackendAudioPlayerNotifiable
  func didElapsedTimeChange() {
    notifyElapsedTimeChanged()
    
    // Throttle play information saves to reduce Core Data overhead
    let now = Date()
    if now.timeIntervalSince(lastPlayInfoSave) >= playInfoSaveInterval {
      lastPlayInfoSave = now
      if let currentItem = currentlyPlaying {
        savePlayInformation(of: currentItem)
      }
    }
  }

  // BackendAudioPlayerNotifiable
  func didLyricsTimeChange(time: CMTime) {
    notifyLyricsTimeChanged(time: time)
  }

  private func savePlayInformation(of playable: AbstractPlayable) {
    let playDuration = backendAudioPlayer.duration
    let playProgress = backendAudioPlayer.elapsedTime
    if playDuration != 0.0, playProgress != 0.0, playable == currentlyPlaying {
      playable.playDuration = Int(playDuration)
      if playProgress > Self.progressTimeStartThreshold,
         playProgress < (playDuration - Self.progressTimeEndThreshold) {
        playable.playProgress = Int(playProgress)
      } else {
        playable.playProgress = 0
      }
    }
  }

  var audioAnalyzer: AudioAnalyzer { backendAudioPlayer.audioAnalyzer }

  func addNotifier(notifier: MusicPlayable) {
    notifierList.append(WeakMusicPlayable(notifier))
  }

  func removeAllNotifier() {
    notifierList.removeAll()
  }

  func notifyItemStartedPlayingFromBeginning() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didStartPlayingFromBeginning()
    }
    seekToLastStoppedPlayTime()
  }

  func notifyItemStartedPlaying() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didStartPlaying()
    }
  }

  // BackendAudioPlayerNotifiable
  func notifyErrorOccurred(error: Error) {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.errorOccurred(error: error)
    }
  }

  func notifyItemPaused() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didPause()
    }
  }

  func notifyPlayerStopped() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didStopPlaying()
    }
  }

  func notifyArtworkChanged() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didArtworkChange()
    }
  }

  func notifyElapsedTimeChanged() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didElapsedTimeChange()
    }
  }

  func notifyLyricsTimeChanged(time: CMTime) {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didLyricsTimeChange(time: time)
    }
  }

  func notifyPlaylistUpdated() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didPlaylistChange()
    }
  }

  func notifyShuffleUpdated() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didShuffleChange()
    }
  }

  func notifyRepeatUpdated() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didRepeatChange()
    }
  }

  func notifyPlaybackRateUpdated() {
    notifierList = notifierList.filter { $0.value != nil }
    for notifier in notifierList {
      notifier.value?.didPlaybackRateChange()
    }
  }
}
