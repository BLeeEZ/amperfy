//
//  BackendAudioPlayer.swift
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
import os.log
import UIKit

// MARK: - BackendAudioPlayerNotifiable

@MainActor
protocol BackendAudioPlayerNotifiable {
  func didElapsedTimeChange()
  func didLyricsTimeChange(time: CMTime) // high refresh count
  func stop()
  func playPrevious()
  func playNext()
  func didItemFinishedPlaying()
  func notifyItemPreparationFinished()
  func notifyErrorOccured(error: Error)
}

// MARK: - PlayType

enum PlayType {
  case stream
  case cache
}

public typealias CreateAVPlayerCallback = () -> AVQueuePlayer
public typealias TriggerReinsertPlayableCallback = @MainActor () -> ()
typealias NextPlayablePreloadCallback = () -> AbstractPlayable?

// MARK: - BackendAudioQueueType

enum BackendAudioQueueType {
  case play
  case queue
}

// MARK: - BackendAudioPlayer

@MainActor
class BackendAudioPlayer: NSObject {
  private let playableDownloader: DownloadManageable
  private let cacheProxy: PlayableFileCachable
  private let backendApi: BackendApi
  private let userStatistics: UserStatistics
  private let createAVPlayerCB: CreateAVPlayerCallback
  private var player: AVQueuePlayer
  private let eventLogger: EventLogger
  private let networkMonitor: NetworkMonitorFacade
  private let updateElapsedTimeInterval = CMTime(
    seconds: 1.0,
    preferredTimescale: CMTimeScale(NSEC_PER_SEC)
  )
  private let updateLyricsTimeInterval = CMTime(
    seconds: 0.1,
    preferredTimescale: CMTimeScale(NSEC_PER_SEC)
  )
  private let fileManager = CacheFileManager.shared
  private var audioSessionHandler: AudioSessionHandler
  private var isTriggerReinsertPlayableAllowed = true
  private var wasPlayingBeforeErrorOccured: Bool = false
  private var userDefinedPlaybackRate: PlaybackRate = .one
  private var nextPreloadedPlayable: AbstractPlayable?
  private var isPreviousPlaylableFinshed = true
  private var isAutoStartPlayback = true
  private var volumePlayer: Float = 1.0

  public var isOfflineMode: Bool = false
  public var isAutoCachePlayedItems: Bool = true
  public var nextPlayablePreloadCB: NextPlayablePreloadCallback?
  public var triggerReinsertPlayableCB: TriggerReinsertPlayableCallback?
  public private(set) var isPlaying: Bool = false
  public private(set) var isErrorOccured: Bool = false
  public private(set) var playType: PlayType?
  public private(set) var streamingMaxBitrates = StreamingMaxBitrates()
  public func setStreamingMaxBitrates(to: StreamingMaxBitrates) {
    let streamingMaxBitrate = streamingMaxBitrates.getActive(networkMonitor: networkMonitor)
    os_log(
      .default,
      "Update Streaming Max Bitrate: %s %s",
      streamingMaxBitrate.description,
      (self.playType == .stream) ? "(active)" : ""
    )
    if playType == .stream {
      player.currentItem?.preferredPeakBitRate = streamingMaxBitrate.asBitsPerSecondAV
    }
  }

  var responder: BackendAudioPlayerNotifiable?
  var volume: Float {
    get {
      volumePlayer
    }
    set {
      volumePlayer = newValue
      player.volume = newValue
    }
  }

  var isPlayableLoaded: Bool {
    player.currentItem?.status == AVPlayerItem.Status.readyToPlay
  }

  var isStopped: Bool {
    playType == nil
  }

  var elapsedTime: Double {
    guard isPlayableLoaded else { return 0.0 }
    let elapsedTimeInSeconds = player.currentTime().seconds
    guard elapsedTimeInSeconds.isFinite else { return 0.0 }
    return elapsedTimeInSeconds
  }

  var duration: Double {
    guard isPlayableLoaded,
          let duration = player.currentItem?.asset.duration.seconds,
          duration.isFinite else {
      return 0.0
    }
    return duration
  }

  var playbackRate: PlaybackRate {
    userDefinedPlaybackRate
  }

  var canBeContinued: Bool {
    player.currentItem != nil
  }

  init(
    createAVPlayerCB: @escaping CreateAVPlayerCallback,
    audioSessionHandler: AudioSessionHandler,
    eventLogger: EventLogger,
    backendApi: BackendApi,
    networkMonitor: NetworkMonitorFacade,
    playableDownloader: DownloadManageable,
    cacheProxy: PlayableFileCachable,
    userStatistics: UserStatistics
  ) {
    self.createAVPlayerCB = createAVPlayerCB
    self.player = createAVPlayerCB()
    self.audioSessionHandler = audioSessionHandler
    self.backendApi = backendApi
    self.networkMonitor = networkMonitor
    self.eventLogger = eventLogger
    self.playableDownloader = playableDownloader
    self.cacheProxy = cacheProxy
    self.userStatistics = userStatistics

    super.init()

    initAVPlayer()
  }

  private func initAVPlayer() {
    player = createAVPlayerCB()
    player.volume = volumePlayer
    player.allowsExternalPlayback = false // Disable video transmission via AirPlay -> only audio
    player.addPeriodicTimeObserver(
      forInterval: updateElapsedTimeInterval,
      queue: DispatchQueue.main
    ) { [weak self] time in
      Task { @MainActor in
        guard let self = self else { return }
        self.checkForPreloadNextPlayerItem()
        self.responder?.didElapsedTimeChange()
      }
    }
    player.addPeriodicTimeObserver(
      forInterval: updateLyricsTimeInterval,
      queue: DispatchQueue.main
    ) { [weak self] time in
      Task { @MainActor in
        guard let self = self else { return }
        self.responder?.didLyricsTimeChange(time: time)
      }
    }
  }

  private func checkForPreloadNextPlayerItem() {
    guard isAutoStartPlayback else { return }
    if nextPreloadedPlayable == nil, elapsedTime.isFinite, elapsedTime > 0, duration.isFinite,
       duration > 0 {
      let remainingTime = duration - elapsedTime
      if remainingTime > 0, remainingTime < 10 {
        nextPreloadedPlayable = nextPlayablePreloadCB?()
        guard let nextPreloadedPlayable = nextPreloadedPlayable else { return }
        os_log(.default, "Preloading: %s", nextPreloadedPlayable.displayString)
        if nextPreloadedPlayable.isCached {
          insertCachedPlayable(playable: nextPreloadedPlayable, queueType: .queue)
        } else if !isOfflineMode {
          Task { @MainActor in
            do {
              try await insertStreamPlayable(playable: nextPreloadedPlayable, queueType: .queue)
              if self.isAutoCachePlayedItems, nextPreloadedPlayable.isDownloadAvailable {
                self.playableDownloader.download(object: nextPreloadedPlayable)
              }
            } catch {
              self.nextPreloadedPlayable = nil
              self.eventLogger.report(topic: "Player", error: error)
            }
          }
        }
      }
    }
  }

  @objc
  private func itemFinishedPlaying() {
    isPreviousPlaylableFinshed = true
    if nextPreloadedPlayable != nil {
      isPlaying = true
    } else {
      isPlaying = false
    }
    responder?.didItemFinishedPlaying()
  }

  @objc
  private func itemPlaybackStalled(_ notification: Notification) {
    Task { @MainActor in
      eventLogger.debug(topic: "Playback stalled", message: "Playback stalled")
      player.pause()
      try await Task.sleep(nanoseconds: 1_000_000_000)
      if self.isPlaying {
        self.player.play()
      }
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if let item = object as? AVPlayerItem {
      if keyPath == "status" {
        Task { @MainActor in
          if item.status == .failed,
             let statusError = item.error {
            handleError(error: statusError)
          } else {
            isTriggerReinsertPlayableAllowed = true
            isErrorOccured = false
          }
        }
      }
    }
  }

  private func handleError(error: Error) {
    isErrorOccured = true
    wasPlayingBeforeErrorOccured = isPlaying
    pause()
    nextPreloadedPlayable = nil
    isPreviousPlaylableFinshed = true
    initAVPlayer()
    eventLogger.report(topic: "Player Status", error: error)
    responder?.notifyErrorOccured(error: error)
    if isTriggerReinsertPlayableAllowed {
      isTriggerReinsertPlayableAllowed = false
      triggerReinsertPlayableCB?()
    }
  }

  func continuePlay() {
    isPlaying = true
    player.play()
    player.playImmediately(atRate: Float(userDefinedPlaybackRate.asDouble))
  }

  func pause() {
    isPlaying = false
    player.pause()
  }

  func stop() {
    isPlaying = false
    clearPlayer()
  }

  func setPlaybackRate(_ newValue: PlaybackRate) {
    userDefinedPlaybackRate = newValue
    player.playImmediately(atRate: Float(newValue.asDouble))
  }

  func seek(toSecond: Double) {
    player.seek(to: CMTime(seconds: toSecond, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
  }

  var shouldPlaybackStart: Bool {
    (!isErrorOccured && isAutoStartPlayback) || (isErrorOccured && wasPlayingBeforeErrorOccured)
  }

  func requestToPlay(
    playable: AbstractPlayable,
    playbackRate: PlaybackRate,
    autoStartPlayback: Bool
  ) {
    userDefinedPlaybackRate = playbackRate
    isAutoStartPlayback = autoStartPlayback
    handleRequest(playable: playable)
  }

  private func handleRequest(playable: AbstractPlayable) {
    if isPreviousPlaylableFinshed, let nextPreloadedPlayable = nextPreloadedPlayable,
       nextPreloadedPlayable == playable {
      // Do nothing next preloaded playable has already been queued to player
      os_log(.default, "Play Preloaded: %s", nextPreloadedPlayable.displayString)
      self.nextPreloadedPlayable = nil
      isPreviousPlaylableFinshed = false
      responder?.notifyItemPreparationFinished()
    } else if let relFilePath = playable.relFilePath,
              fileManager.fileExits(relFilePath: relFilePath) {
      nextPreloadedPlayable = nil
      guard playable.isPlayableOniOS else {
        reactToIncompatibleContentType(
          contentType: playable.fileContentType ?? "",
          playableDisplayTitle: playable.displayString
        )
        return
      }
      insertCachedPlayable(playable: playable)
      if shouldPlaybackStart {
        continuePlay()
      } else {
        isPlaying = false
      }
      responder?.notifyItemPreparationFinished()
    } else if !isOfflineMode {
      nextPreloadedPlayable = nil
      guard playable.isPlayableOniOS || backendApi.isStreamingTranscodingActive else {
        reactToIncompatibleContentType(
          contentType: playable.fileContentType ?? "",
          playableDisplayTitle: playable.displayString
        )
        return
      }
      if let radio = playable.asRadio {
        // radios must have a valid URL
        guard let urlString = radio.url,
              URL(string: urlString) != nil
        else {
          reactToInvalidRadioUrl(playableDisplayTitle: playable.displayString)
          return
        }
      }

      stop()
      Task { @MainActor in
        do {
          try await insertStreamPlayable(playable: playable)
          if self.isAutoCachePlayedItems, !playable.isRadio {
            self.playableDownloader.download(object: playable)
          }
          if self.shouldPlaybackStart {
            self.continuePlay()
          } else {
            self.isPlaying = false
          }
          self.responder?.notifyItemPreparationFinished()
        } catch {
          self.responder?.notifyErrorOccured(error: error)
          self.responder?.notifyItemPreparationFinished()
          self.eventLogger.report(topic: "Player", error: error)
        }
      }
    } else {
      clearPlayer()
      responder?.notifyItemPreparationFinished()
    }
  }

  private func reactToIncompatibleContentType(contentType: String, playableDisplayTitle: String) {
    clearPlayer()
    eventLogger.info(
      topic: "Player Info",
      statusCode: .playerError,
      message: "Content type \"\(contentType)\" of \"\(playableDisplayTitle)\" is not playable via Amperfy. Activating transcoding in Settings could resolve this issue.",
      displayPopup: true
    )
    responder?.notifyItemPreparationFinished()
  }

  private func reactToInvalidRadioUrl(playableDisplayTitle: String) {
    clearPlayer()
    eventLogger.info(
      topic: "Player Info",
      statusCode: .playerError,
      message: "Radio \"\(playableDisplayTitle)\" has an invalid stream URL.",
      displayPopup: true
    )
    responder?.notifyItemPreparationFinished()
  }

  private func clearPlayer() {
    isPreviousPlaylableFinshed = true
    nextPreloadedPlayable = nil
    isPlaying = false
    playType = nil
    player.pause()
    playInPlayer(item: nil, queueType: .play)
  }

  private func insertCachedPlayable(
    playable: AbstractPlayable,
    queueType: BackendAudioQueueType = .play
  ) {
    guard let fileURL = cacheProxy.getFileURL(forPlayable: playable) else {
      return
    }
    if queueType == .play {
      os_log(.default, "Play Cache: %s (%s)", playable.displayString, fileURL.absoluteString)
    } else {
      os_log(.default, "Insert Cache: %s (%s)", playable.displayString, fileURL.absoluteString)
    }
    playType = .cache
    if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
    insert(playable: playable, withUrl: fileURL, queueType: queueType)
  }

  @MainActor
  private func insertStreamPlayable(
    playable: AbstractPlayable,
    queueType: BackendAudioQueueType = .play
  ) async throws {
    let streamingMaxBitrate = streamingMaxBitrates.getActive(networkMonitor: networkMonitor)

    @MainActor
    func provideUrl() async throws -> URL {
      if let radio = playable.asRadio {
        guard let streamUrlString = radio.url,
              let streamUrl = URL(string: streamUrlString)
        else {
          throw BackendError.invalidUrl
        }
        return streamUrl
      } else {
        return try await backendApi.generateUrl(
          forStreamingPlayable: playable.info,
          maxBitrate: streamingMaxBitrate
        )
      }
    }
    let streamUrl = try await provideUrl()

    if queueType == .play {
      os_log(
        .default,
        "Play Stream: %s (%s)",
        playable.displayString,
        streamingMaxBitrate.description
      )
    } else {
      os_log(
        .default,
        "Insert Stream: %s (%s)",
        playable.displayString,
        streamingMaxBitrate.description
      )
    }
    playType = .stream
    if playable.isSong { userStatistics.playedSong(isPlayedFromCache: false) }
    insert(
      playable: playable,
      withUrl: streamUrl,
      streamingMaxBitrate: streamingMaxBitrate,
      queueType: queueType
    )
  }

  private func insert(
    playable: AbstractPlayable,
    withUrl url: URL,
    streamingMaxBitrate: StreamingMaxBitratePreference = .noLimit,
    queueType: BackendAudioQueueType
  ) {
    if queueType == .play {
      player.pause()
      audioSessionHandler.configureBackgroundPlayback()
    }

    var item: AVPlayerItem?
    if let mimeType = playable.iOsCompatibleContentType {
      let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])
      item = AVPlayerItem(asset: asset)
    } else {
      item = AVPlayerItem(url: url)
    }
    item?.preferredPeakBitRate = streamingMaxBitrate.asBitsPerSecondAV
    addObservers(playerItem: item)
    playInPlayer(item: item, queueType: queueType)
  }

  private func addObservers(playerItem: AVPlayerItem?) {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(itemFinishedPlaying),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: playerItem
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(itemPlaybackStalled(_:)),
      name: NSNotification.Name.AVPlayerItemPlaybackStalled,
      object: playerItem
    )
    playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
  }

  private func playInPlayer(
    item: AVPlayerItem?,
    queueType: BackendAudioQueueType
  ) {
    switch queueType {
    case .play:
      player.removeAllItems()
      initAVPlayer()
      player.replaceCurrentItem(with: item)
      isPreviousPlaylableFinshed = false
    case .queue:
      if let item = item {
        player.insert(item, after: nil)
      } else {
        player.removeAllItems()
      }
    }
  }
}
