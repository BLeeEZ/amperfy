//
//  RemoteCommandCenterHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 23.11.21.
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
import MediaPlayer

// MARK: - RemoteCommandCenterHandler

@MainActor
class RemoteCommandCenterHandler {
  private var musicPlayer: PlayerFacade
  private let backendAudioPlayer: BackendAudioPlayer
  private let librarySyncer: LibrarySyncer
  private let eventLogger: EventLogger
  private let remoteCommandCenter: MPRemoteCommandCenter

  init(
    musicPlayer: PlayerFacade,
    backendAudioPlayer: BackendAudioPlayer,
    librarySyncer: LibrarySyncer,
    eventLogger: EventLogger,
    remoteCommandCenter: MPRemoteCommandCenter
  ) {
    self.musicPlayer = musicPlayer
    self.backendAudioPlayer = backendAudioPlayer
    self.librarySyncer = librarySyncer
    self.eventLogger = eventLogger
    self.remoteCommandCenter = remoteCommandCenter
  }

  func configureRemoteCommands() {
    remoteCommandCenter.playCommand.isEnabled = true
    remoteCommandCenter.playCommand.addTarget(handler: { event in
      self.musicPlayer.play()
      return .success
    })

    remoteCommandCenter.pauseCommand.isEnabled = true
    remoteCommandCenter.pauseCommand.addTarget(handler: { event in
      self.musicPlayer.pause()
      return .success
    })

    remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
    remoteCommandCenter.togglePlayPauseCommand.addTarget(handler: { event in
      self.musicPlayer.togglePlayPause()
      return .success
    })

    remoteCommandCenter.stopCommand.isEnabled = true
    remoteCommandCenter.stopCommand.addTarget(handler: { event in
      self.musicPlayer.pause()
      return .success
    })

    remoteCommandCenter.previousTrackCommand.isEnabled = true
    remoteCommandCenter.previousTrackCommand.addTarget(handler: { event in
      switch self.musicPlayer.playerMode {
      case .music:
        self.musicPlayer.playPreviousOrReplay()
      case .podcast:
        self.musicPlayer.skipBackward(interval: self.musicPlayer.skipBackwardPodcastInterval)
      }
      return .success
    })

    remoteCommandCenter.nextTrackCommand.isEnabled = true
    remoteCommandCenter.nextTrackCommand.addTarget(handler: { event in
      switch self.musicPlayer.playerMode {
      case .music:
        self.musicPlayer.playNext()
      case .podcast:
        self.musicPlayer.skipForward(interval: self.musicPlayer.skipForwardPodcastInterval)
      }
      return .success
    })

    remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
    remoteCommandCenter.changeRepeatModeCommand.addTarget(handler: { event in
      guard let command = event as? MPChangeRepeatModeCommandEvent else { return .noSuchContent }
      self.musicPlayer.setRepeatMode(RepeatMode.fromMPRepeatType(type: command.repeatType))
      return .success
    })

    remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
    remoteCommandCenter.changeShuffleModeCommand.addTarget(handler: { event in
      guard let command = event as? MPChangeShuffleModeCommandEvent else { return .noSuchContent }
      if (command.shuffleType == .off && self.musicPlayer.isShuffle) ||
        (command.shuffleType != .off && !self.musicPlayer.isShuffle) {}
      self.musicPlayer.toggleShuffle()
      return .success
    })

    remoteCommandCenter.skipBackwardCommand.isEnabled = true
    remoteCommandCenter.skipBackwardCommand
      .preferredIntervals = [NSNumber(value: musicPlayer.skipBackwardPodcastInterval)]
    remoteCommandCenter.skipBackwardCommand.addTarget(handler: { event in
      self.musicPlayer.skipBackward(interval: self.musicPlayer.skipBackwardPodcastInterval)
      return .success
    })

    remoteCommandCenter.skipForwardCommand.isEnabled = true
    remoteCommandCenter.skipForwardCommand
      .preferredIntervals = [NSNumber(value: musicPlayer.skipForwardPodcastInterval)]
    remoteCommandCenter.skipForwardCommand.addTarget(handler: { event in
      self.musicPlayer.skipForward(interval: self.musicPlayer.skipForwardPodcastInterval)
      return .success
    })

    remoteCommandCenter.changePlaybackRateCommand.isEnabled = true
    remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = PlaybackRate.allCases
      .map { NSNumber(value: $0.asDouble) }
    remoteCommandCenter.changePlaybackRateCommand.addTarget(handler: { event in
      guard let command = event as? MPChangePlaybackRateCommandEvent else { return .noSuchContent }
      let playbackRate = PlaybackRate.create(from: Double(command.playbackRate))
      self.musicPlayer.setPlaybackRate(playbackRate)
      return .success
    })

    remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
    remoteCommandCenter.changePlaybackPositionCommand.addTarget(handler: { event in
      guard let command = event as? MPChangePlaybackPositionCommandEvent
      else { return .noSuchContent }
      let cmTime = CMTime(
        seconds: command.positionTime,
        preferredTimescale: CMTimeScale(NSEC_PER_SEC)
      )
      self.musicPlayer.seek(toSecond: cmTime.seconds)
      return .success
    })

    #if false // Deactivated => How to test rating change on simulater/real device?
      remoteCommandCenter.ratingCommand.isEnabled = true
      remoteCommandCenter.ratingCommand.minimumRating = 0.0
      remoteCommandCenter.ratingCommand.maximumRating = 5.0
      remoteCommandCenter.ratingCommand.addTarget(handler: { event in
        guard let command = event as? MPRatingCommandEvent,
              let currentItem = self.musicPlayer.currentlyPlaying,
              currentItem.isRateable,
              let song = currentItem.asSong
        else { return .noSuchContent }

        let rating = Int(command.rating)
        firstly {
          self.librarySyncer.setRating(song: song, rating: rating)
        }.catch { error in
          self.eventLogger.report(topic: "Song Rating Sync", error: error)
        }
        return .success
      })
    #endif

    remoteCommandCenter.likeCommand.isEnabled = true
    remoteCommandCenter.likeCommand.localizedTitle = NSLocalizedString(
      "Favorite",
      comment: "Marks the currently playing element as favorite"
    )
    remoteCommandCenter.likeCommand.addTarget(handler: { event in
      guard let command = event as? MPFeedbackCommandEvent,
            let currentItem = self.musicPlayer.currentlyPlaying,
            currentItem.isFavoritable
      else { return .noSuchContent }
      guard command.isNegative == currentItem.isFavorite else {
        self.remoteCommandCenter.likeCommand.isActive = currentItem.isFavorite
        return .success
      }
      self.remoteCommandCenter.likeCommand.isActive = !command.isNegative
      Task { @MainActor in
        do {
          try await currentItem.remoteToggleFavorite(syncer: self.librarySyncer)
        } catch {
          self.eventLogger.report(topic: "Toggle Favorite", error: error)
        }
      }
      return .success
    })
  }

  private func changeRemoteCommandCenterControlsBasedOnCurrentPlayableType() {
    guard let currentItem = musicPlayer.currentlyPlaying else { return }
    switch currentItem.derivedType {
    case .song:
      remoteCommandCenter.playCommand.isEnabled = true
      remoteCommandCenter.pauseCommand.isEnabled = true
      remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
      remoteCommandCenter.stopCommand.isEnabled = false
      remoteCommandCenter.previousTrackCommand.isEnabled = true
      remoteCommandCenter.nextTrackCommand.isEnabled = true
      remoteCommandCenter.skipBackwardCommand.isEnabled = false
      remoteCommandCenter.skipForwardCommand.isEnabled = false
      remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
      remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
      remoteCommandCenter.likeCommand.isEnabled = true
      remoteCommandCenter.likeCommand.isActive = currentItem.isFavorite
      remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
      remoteCommandCenter.changePlaybackRateCommand.isEnabled = true
    case .podcastEpisode:
      remoteCommandCenter.playCommand.isEnabled = true
      remoteCommandCenter.pauseCommand.isEnabled = true
      remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
      remoteCommandCenter.stopCommand.isEnabled = false
      remoteCommandCenter.previousTrackCommand.isEnabled = false
      remoteCommandCenter.nextTrackCommand.isEnabled = false
      remoteCommandCenter.skipBackwardCommand.isEnabled = true
      remoteCommandCenter.skipForwardCommand.isEnabled = true
      remoteCommandCenter.changeShuffleModeCommand.isEnabled = false
      remoteCommandCenter.changeRepeatModeCommand.isEnabled = false
      remoteCommandCenter.likeCommand.isEnabled = false
      remoteCommandCenter.likeCommand.isActive = false
      remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
      remoteCommandCenter.changePlaybackRateCommand.isEnabled = true
    case .radio:
      remoteCommandCenter.playCommand.isEnabled = true
      remoteCommandCenter.pauseCommand.isEnabled = false
      remoteCommandCenter.togglePlayPauseCommand.isEnabled = false
      remoteCommandCenter.stopCommand.isEnabled = true
      remoteCommandCenter.previousTrackCommand.isEnabled = true
      remoteCommandCenter.nextTrackCommand.isEnabled = true
      remoteCommandCenter.skipBackwardCommand.isEnabled = false
      remoteCommandCenter.skipForwardCommand.isEnabled = false
      remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
      remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
      remoteCommandCenter.likeCommand.isEnabled = false
      remoteCommandCenter.likeCommand.isActive = false
      remoteCommandCenter.changePlaybackPositionCommand.isEnabled = false
      remoteCommandCenter.changePlaybackRateCommand.isEnabled = false
    }
    updateShuffle()
    updateRepeat()
  }

  private func updateShuffle() {
    remoteCommandCenter.changeShuffleModeCommand.currentShuffleType = musicPlayer
      .isShuffle ? .items : .off
  }

  private func updateRepeat() {
    remoteCommandCenter.changeRepeatModeCommand.currentRepeatType = musicPlayer.repeatMode
      .asMPRepeatType
  }
}

// MARK: MusicPlayable

extension RemoteCommandCenterHandler: MusicPlayable {
  func didStartPlayingFromBeginning() {}
  func didStartPlaying() {
    changeRemoteCommandCenterControlsBasedOnCurrentPlayableType()
  }

  func didPause() {}
  func didStopPlaying() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}

  func didShuffleChange() {
    updateShuffle()
  }

  func didRepeatChange() {
    updateRepeat()
  }
}
