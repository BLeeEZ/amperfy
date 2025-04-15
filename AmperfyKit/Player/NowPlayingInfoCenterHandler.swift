//
//  NowPlayingInfoCenterHandler.swift
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

// MARK: - NowPlayingInfoCenterHandler

@MainActor
class NowPlayingInfoCenterHandler {
  private let musicPlayer: AudioPlayer
  private let backendAudioPlayer: BackendAudioPlayer
  private let storage: PersistentStorage
  private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
  private let artworkDownloadManager: DownloadManageable

  init(
    musicPlayer: AudioPlayer,
    backendAudioPlayer: BackendAudioPlayer,
    nowPlayingInfoCenter: MPNowPlayingInfoCenter,
    storage: PersistentStorage,
    notificationHandler: EventNotificationHandler,
    artworkDownloadManager: DownloadManageable,
    playableDownloadManager: DownloadManageable
  ) {
    self.musicPlayer = musicPlayer
    self.backendAudioPlayer = backendAudioPlayer
    self.nowPlayingInfoCenter = nowPlayingInfoCenter
    self.storage = storage
    self.artworkDownloadManager = artworkDownloadManager

    nowPlayingInfoCenter.playbackState = .stopped

    notificationHandler.register(
      self,
      selector: #selector(downloadFinishedSuccessful(notification:)),
      name: .downloadFinishedSuccess,
      object: artworkDownloadManager
    )
    notificationHandler.register(
      self,
      selector: #selector(downloadFinishedSuccessful(notification:)),
      name: .downloadFinishedSuccess,
      object: playableDownloadManager
    )
  }

  func updateNowPlayingInfo(playable: AbstractPlayable) {
    let albumTitle = playable.asSong?.album?.name ?? ""

    let artworkImage = LibraryEntityImage.getImageToDisplayImmediately(
      libraryEntity: playable,
      themePreference: storage.settings.themePreference,
      artworkDisplayPreference: storage.settings.artworkDisplayPreference,
      useCache: true
    )
    if let artwork = playable.artwork {
      artworkDownloadManager.download(object: artwork)
    }

    nowPlayingInfoCenter.nowPlayingInfo = [
      MPNowPlayingInfoPropertyMediaType: NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue),
      MPNowPlayingInfoPropertyServiceIdentifier: AmperKit.name,

      MPMediaItemPropertyIsCloudItem: !playable.isCached,
      MPMediaItemPropertyTitle: playable.title,
      MPMediaItemPropertyAlbumTitle: albumTitle,
      MPMediaItemPropertyArtist: playable.creatorName,

      MPMediaItemPropertyPlaybackDuration: backendAudioPlayer.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: backendAudioPlayer.elapsedTime,
      MPNowPlayingInfoPropertyIsLiveStream: playable.isRadio,

      MPNowPlayingInfoPropertyDefaultPlaybackRate: NSNumber(value: 1.0),
      MPNowPlayingInfoPropertyPlaybackRate: NSNumber(
        value: backendAudioPlayer.playbackRate
          .asDouble
      ),

      MPMediaItemPropertyArtwork: MPMediaItemArtwork(
        boundsSize: artworkImage.size,
        requestHandler: { @Sendable size -> UIImage in
          // this completion handler is not called in main thread!
          return artworkImage
        }
      ),
    ]
  }

  @objc
  private func downloadFinishedSuccessful(notification: Notification) {
    guard let downloadNotification = DownloadNotification.fromNotification(notification),
          let curPlayable = musicPlayer.currentlyPlaying
    else { return }
    if curPlayable.uniqueID == downloadNotification.id {
      Task { @MainActor in
        updateNowPlayingInfo(playable: curPlayable)
      }
    }
    if let artwork = curPlayable.artwork,
       artwork.uniqueID == downloadNotification.id {
      Task { @MainActor in
        updateNowPlayingInfo(playable: curPlayable)
      }
    }
  }
}

// MARK: MusicPlayable

extension NowPlayingInfoCenterHandler: MusicPlayable {
  func didStartPlayingFromBeginning() {}

  func didStartPlaying() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
    nowPlayingInfoCenter.playbackState = .playing
  }

  func didPause() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
    nowPlayingInfoCenter.nowPlayingInfo = [:]
    nowPlayingInfoCenter.playbackState = .paused
  }

  func didStopPlaying() {
    nowPlayingInfoCenter.nowPlayingInfo = nil
    nowPlayingInfoCenter.playbackState = .stopped
  }

  func didElapsedTimeChange() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
  }

  func didPlaylistChange() {}

  func didArtworkChange() {}
}
