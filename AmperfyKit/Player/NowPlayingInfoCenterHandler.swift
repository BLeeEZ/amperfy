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
public class NowPlayingInfoCenterHandler {
  private let musicPlayer: AudioPlayer
  private let backendAudioPlayer: BackendAudioPlayer
  private let storage: PersistentStorage
  private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
  private let getArtworkDownloaderCB: GetArtworkDownloadManagerCallback
  private var accountNotificationHandler: AccountNotificationHandler?

  init(
    musicPlayer: AudioPlayer,
    backendAudioPlayer: BackendAudioPlayer,
    nowPlayingInfoCenter: MPNowPlayingInfoCenter,
    storage: PersistentStorage,
    notificationHandler: EventNotificationHandler,
    getArtworkDownloaderCB: @escaping GetArtworkDownloadManagerCallback,
    getPlayableDownloaderCB: @escaping GetPlayableDownloadManagerCallback
  ) {
    self.musicPlayer = musicPlayer
    self.backendAudioPlayer = backendAudioPlayer
    self.nowPlayingInfoCenter = nowPlayingInfoCenter
    self.storage = storage
    self.getArtworkDownloaderCB = getArtworkDownloaderCB

    nowPlayingInfoCenter.playbackState = .stopped

    self.accountNotificationHandler = AccountNotificationHandler(
      storage: storage,
      notificationHandler: notificationHandler
    )
    accountNotificationHandler?.registerCallbackForAllAccounts { [weak self] accountInfo in
      guard let self else { return }
      notificationHandler.register(
        self,
        selector: #selector(downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: getArtworkDownloaderCB(accountInfo)
      )
      notificationHandler.register(
        self,
        selector: #selector(downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: getPlayableDownloaderCB(accountInfo)
      )
    }
  }

  private func updateNowPlayingInfo(playable: AbstractPlayable) {
    let albumTitle = playable.asSong?.album?.name ?? ""

    var artworkImage = UIImage()
    if let accountInfo = playable.account?.info {
      artworkImage = LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: playable,
        themePreference: storage.settings.accounts.getSetting(accountInfo).read.themePreference,
        artworkDisplayPreference: storage.settings.accounts.getSetting(accountInfo).read
          .artworkDisplayPreference,
        useCache: true
      )
      if let artwork = playable.artwork {
        getArtworkDownloaderCB(accountInfo).download(object: artwork)
      }
    }

    let concurrentSafeArtworkImage = artworkImage
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
        boundsSize: concurrentSafeArtworkImage.size,
        requestHandler: { @Sendable size -> UIImage in
          // this completion handler is not called in main thread!
          return concurrentSafeArtworkImage
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
  public func didStartPlayingFromBeginning() {}

  public func didStartPlaying() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
    nowPlayingInfoCenter.playbackState = .playing
  }

  public func didPause() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
    nowPlayingInfoCenter.playbackState = .paused
  }

  public func didStopPlaying() {
    nowPlayingInfoCenter.nowPlayingInfo = nil
    nowPlayingInfoCenter.playbackState = .stopped
  }

  public func didElapsedTimeChange() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
  }

  public func didPlaylistChange() {}

  public func didArtworkChange() {}

  public func didShuffleChange() {}

  public func didRepeatChange() {}

  public func didPlaybackRateChange() {}
}
