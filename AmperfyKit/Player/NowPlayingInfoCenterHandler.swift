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
  private var published: PublishedNowPlaying?

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
    let nowPlaying = displayNowPlayingInfo(for: playable)
    let timing = currentTiming()

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
    let info: [String: Any] = [
      MPNowPlayingInfoPropertyMediaType: NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue),
      MPNowPlayingInfoPropertyServiceIdentifier: AmperKit.name,

      MPMediaItemPropertyIsCloudItem: !playable.isCached,
      MPMediaItemPropertyTitle: nowPlaying.title,
      MPMediaItemPropertyAlbumTitle: albumTitle,
      MPMediaItemPropertyArtist: nowPlaying.artist,

      MPMediaItemPropertyPlaybackDuration: timing.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: timing.elapsedTime,
      MPNowPlayingInfoPropertyIsLiveStream: playable.isRadio,

      MPNowPlayingInfoPropertyDefaultPlaybackRate: NSNumber(value: 1.0),
      MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: timing.playbackRate),

      MPMediaItemPropertyArtwork: MPMediaItemArtwork(
        boundsSize: concurrentSafeArtworkImage.size,
        requestHandler: { @Sendable size -> UIImage in
          // this completion handler is not called in main thread!
          NowPlayingArtwork.image(concurrentSafeArtworkImage, fittingIn: size)
        }
      ),
    ]
    nowPlayingInfoCenter.nowPlayingInfo = info
    published = PublishedNowPlaying(playableID: playable.uniqueID, info: info, timing: timing)
  }

  private func currentTiming() -> NowPlayingTiming {
    NowPlayingTiming(
      elapsedTime: backendAudioPlayer.elapsedTime,
      duration: backendAudioPlayer.duration,
      playbackRate: backendAudioPlayer.playbackRate.asDouble,
      measuredAt: ProcessInfo.processInfo.systemUptime
    )
  }

  private func refreshTimingIfDrifted() {
    guard var published else { return }
    let timing = currentTiming()
    guard published.timing.needsRefresh(comparedTo: timing) else { return }
    published.info[MPMediaItemPropertyPlaybackDuration] = timing.duration
    published.info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = timing.elapsedTime
    published.info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: timing.playbackRate)
    published.timing = timing
    nowPlayingInfoCenter.nowPlayingInfo = published.info
    self.published = published
  }

  private func displayNowPlayingInfo(for playable: AbstractPlayable) -> RadioNowPlayingInfo {
    if playable.isRadio,
       let radioInfo = musicPlayer.currentRadioNowPlaying,
       !radioInfo.isEmpty {
      return radioInfo
    }
    return RadioNowPlayingInfo(title: playable.title, artist: playable.creatorName)
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
    published = nil
  }

  public func didElapsedTimeChange() {
    guard let curPlayable = musicPlayer.currentlyPlaying else { return }
    if curPlayable.uniqueID == published?.playableID {
      refreshTimingIfDrifted()
    } else {
      updateNowPlayingInfo(playable: curPlayable)
    }
  }

  public func didPlaylistChange() {}

  public func didArtworkChange() {}

  public func didNowPlayingInfoChange() {
    if let curPlayable = musicPlayer.currentlyPlaying {
      updateNowPlayingInfo(playable: curPlayable)
    }
  }

  public func didShuffleChange() {}

  public func didRepeatChange() {}

  public func didPlaybackRateChange() {}
}

// MARK: - PublishedNowPlaying

private struct PublishedNowPlaying {
  let playableID: String
  var info: [String: Any]
  var timing: NowPlayingTiming
}

// MARK: - NowPlayingTiming

struct NowPlayingTiming {
  static let driftTolerance: TimeInterval = 1.0

  let elapsedTime: Double
  let duration: Double
  let playbackRate: Double
  let measuredAt: TimeInterval

  func needsRefresh(comparedTo current: NowPlayingTiming) -> Bool {
    let extrapolatedElapsedTime = elapsedTime + (current.measuredAt - measuredAt) * playbackRate
    return current.playbackRate != playbackRate ||
      !Self.isWithinDriftTolerance(current.duration, duration) ||
      !Self.isWithinDriftTolerance(current.elapsedTime, extrapolatedElapsedTime)
  }

  private static func isWithinDriftTolerance(_ lhs: Double, _ rhs: Double) -> Bool {
    abs(lhs - rhs) <= driftTolerance
  }
}

// MARK: - NowPlayingArtwork

enum NowPlayingArtwork {
  static func image(_ image: UIImage, fittingIn requestedSize: CGSize) -> UIImage {
    let scale = min(
      requestedSize.width / image.size.width,
      requestedSize.height / image.size.height
    )
    guard scale > 0, scale < 1 else { return image }
    let fittingSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    return image.preparingThumbnail(of: fittingSize) ?? image
  }
}
