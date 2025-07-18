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

import AudioStreaming
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
  func notifyErrorOccurred(error: Error)
}

// MARK: - AudioStreamingPlayer

public class AudioStreamingPlayer: AudioStreaming.AudioPlayer {
  public func elapsedTime() -> Double {
    progress
  }

  public func getState() -> AudioStreaming.AudioPlayerState {
    state
  }
}

// MARK: - PlayType

enum PlayType {
  case stream
  case cache
}

public typealias CreateAudioStreamingPlayerCallback = () -> AudioStreamingPlayer
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
  private let createAudioStreamingPlayerCB: CreateAudioStreamingPlayerCallback
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
  private var wasPlayingBeforeErrorOccurred: Bool = false
  private var userDefinedPlaybackRate: PlaybackRate = .one
  private var currentPreparedUrl: String = ""
  private var currentPlayUrl: String = ""
  private var nextPreloadedPlayable: AbstractPlayable?
  private var nextPreloadedUrl: String = ""
  private var isPreviousPlaylableFinshed = true
  private var isAutoStartPlayback = true
  private var seekTimeWhenStarted: Double?
  private var timerElapsedTimeInterval: Timer?
  private var timerLyricsTimeInterval: Timer?
  private var volumePlayer: Float = 1.0

  private var player: AudioStreamingPlayer?
  private var equalizer: AVAudioUnitEQ?
  private var replayGainNode: AVAudioMixerNode?

  // ReplayGain Settings
  private var isReplayGainEnabled: Bool = true
  private var currentReplayGainValue: Float = 0.0 // ReplayGain in dB
  // EQ Settings
  private var equalizerVolumeCompensation: Float = 1.0
  private var isEqualizerEnabled: Bool = true
  private var currentEqualizerConfig: EqualizerConfig = .off

  public var isOfflineMode: Bool = false
  public var isAutoCachePlayedItems: Bool = true
  public var nextPlayablePreloadCB: NextPlayablePreloadCallback?
  public var triggerReinsertPlayableCB: TriggerReinsertPlayableCallback?
  public private(set) var isPlaying: Bool = false
  public private(set) var isErrorOccurred: Bool = false
  public private(set) var playType: PlayType?
  public private(set) var streamingMaxBitrates = StreamingMaxBitrates()
  public func setStreamingMaxBitrates(to: StreamingMaxBitrates) {
    let oldBitrate = streamingMaxBitrates.getActive(networkMonitor: networkMonitor)
    let newBitrate = to.getActive(networkMonitor: networkMonitor)

    os_log(
      .default,
      "Update Streaming Max Bitrate: %s -> %s (for next stream)",
      oldBitrate.description,
      newBitrate.description
    )
    // Update the stored bitrates
    streamingMaxBitrates = to
  }

  var responder: BackendAudioPlayerNotifiable?
  var volume: Float {
    get {
      volumePlayer
    }
    set {
      volumePlayer = newValue
      player?.volume = newValue
    }
  }

  var isStopped: Bool {
    playType == nil
  }

  var elapsedTime: Double {
    player?.elapsedTime() ?? 0.0
  }

  var duration: Double {
    player?.duration ?? 0.0
  }

  var playbackRate: PlaybackRate {
    userDefinedPlaybackRate
  }

  var canBeContinued: Bool {
    currentPlayUrl != "" &&
      (
        player?.getState() == .paused || player?.getState() == .playing || player?
          .getState() == .bufferring
      )
  }

  init(
    createAudioStreamingPlayerCB: @escaping CreateAudioStreamingPlayerCallback,
    audioSessionHandler: AudioSessionHandler,
    eventLogger: EventLogger,
    backendApi: BackendApi,
    networkMonitor: NetworkMonitorFacade,
    playableDownloader: DownloadManageable,
    cacheProxy: PlayableFileCachable,
    userStatistics: UserStatistics
  ) {
    self.createAudioStreamingPlayerCB = createAudioStreamingPlayerCB
    self.audioSessionHandler = audioSessionHandler
    self.backendApi = backendApi
    self.networkMonitor = networkMonitor
    self.eventLogger = eventLogger
    self.playableDownloader = playableDownloader
    self.cacheProxy = cacheProxy
    self.userStatistics = userStatistics

    super.init()

    initAudioStreamingPlayerAndNodes()
  }

  private func startTimers() {
    stopTimers()
    timerElapsedTimeInterval = Timer.scheduledTimer(
      withTimeInterval: updateElapsedTimeInterval.seconds,
      repeats: true
    ) { [weak self] timer in
      Task { @MainActor in
        guard let self = self else { return }
        self.checkForPreloadNextPlayerItem()
        self.responder?.didElapsedTimeChange()
      }
    }
    timerLyricsTimeInterval = Timer.scheduledTimer(
      withTimeInterval: updateLyricsTimeInterval.seconds,
      repeats: true
    ) { [weak self] timer in
      Task { @MainActor in
        guard let self = self else { return }
        let cmTime = CMTime(value: Int64(self.elapsedTime * 1_000), timescale: 1_000)
        self.responder?.didLyricsTimeChange(time: cmTime)
      }
    }
  }

  private func stopTimers() {
    timerElapsedTimeInterval?.invalidate()
    timerLyricsTimeInterval?.invalidate()
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

  @MainActor
  private func itemFinishedPlaying() {
    isTriggerReinsertPlayableAllowed = true
    isPreviousPlaylableFinshed = true
    if nextPreloadedPlayable != nil {
      isPlaying = true
      startTimers()
    } else {
      isPlaying = false
      stopTimers()
    }
    responder?.didItemFinishedPlaying()
  }

  private func handleError(error: Error) {
    isErrorOccurred = true
    wasPlayingBeforeErrorOccurred = isPlaying
    pause()
    nextPreloadedPlayable = nil
    nextPreloadedUrl = ""
    isPreviousPlaylableFinshed = true
    restartPlayer()
    eventLogger.report(topic: "Player Status", error: error)
    responder?.notifyErrorOccurred(error: error)
    if isTriggerReinsertPlayableAllowed {
      isTriggerReinsertPlayableAllowed = false
      triggerReinsertPlayableCB?()
    }
  }

  func continuePlay() {
    isPlaying = true
    player?.resume()
    startTimers()
    player?.rate = Float(userDefinedPlaybackRate.asDouble)
  }

  func pause() {
    isPlaying = false
    player?.pause()
    stopTimers()
  }

  func stop() {
    isPlaying = false
    clearPlayer()
  }

  func setPlaybackRate(_ newValue: PlaybackRate) {
    userDefinedPlaybackRate = newValue
    player?.rate = Float(newValue.asDouble)
  }

  func seek(toSecond: Double) {
    if currentPlayUrl != "", player?.getState() == .playing || player?.getState() == .paused {
      seekTimeWhenStarted = nil
      player?.seek(to: toSecond)
    } else {
      seekTimeWhenStarted = toSecond
    }
  }

  private func restartPlayer() {
    player = nil
    initAudioStreamingPlayerAndNodes()
  }

  private func initAudioStreamingPlayerAndNodes() {
    guard player == nil else { return }
    player = createAudioStreamingPlayerCB()

    equalizer = AVAudioUnitEQ(numberOfBands: 10)
    replayGainNode = AVAudioMixerNode()

    guard let player,
          let eq = equalizer,
          let replayGain = replayGainNode
    else { return }

    player.volume = volumePlayer
    player.delegate = self

    player.attach(nodes: [eq, replayGain])

    setupEqualizerBands()
    applyEqualizerConfig(eqConfig: currentEqualizerConfig)
    applyReplayGain()
    os_log(.default, "Player setup completed with EQ and ReplayGain support")
  }

  var shouldPlaybackStart: Bool {
    (!isErrorOccurred && isAutoStartPlayback) || (isErrorOccurred && wasPlayingBeforeErrorOccurred)
  }

  func requestToPlay(
    playable: AbstractPlayable,
    playbackRate: PlaybackRate,
    autoStartPlayback: Bool
  ) {
    userDefinedPlaybackRate = playbackRate
    player?.rate = Float(userDefinedPlaybackRate.asDouble)
    isAutoStartPlayback = autoStartPlayback
    handleRequest(playable: playable)
  }

  private func handleRequest(playable: AbstractPlayable) {
    if isPreviousPlaylableFinshed, let nextPreloadedPlayable = nextPreloadedPlayable,
       nextPreloadedPlayable == playable {
      // Do nothing next preloaded playable has already been queued to player
      os_log(.default, "Play Preloaded: %s", nextPreloadedPlayable.displayString)
      currentPreparedUrl = ""
      currentPlayUrl = nextPreloadedUrl
      isPreviousPlaylableFinshed = false
      currentReplayGainValue = nextPreloadedPlayable.replayGainTrackGain
      applyReplayGain()
      self.nextPreloadedPlayable = nil
      nextPreloadedUrl = ""
      responder?.notifyItemPreparationFinished()
    } else if let relFilePath = playable.relFilePath,
              fileManager.fileExits(relFilePath: relFilePath) {
      currentPlayUrl = ""
      nextPreloadedPlayable = nil
      nextPreloadedUrl = ""
      guard playable.isPlayableOniOS else {
        reactToIncompatibleContentType(
          contentType: playable.fileContentType ?? "",
          playableDisplayTitle: playable.displayString
        )
        return
      }
      currentReplayGainValue = playable.replayGainTrackGain
      applyReplayGain()
      insertCachedPlayable(playable: playable)
      isPlaying = shouldPlaybackStart
      responder?.notifyItemPreparationFinished()
    } else if !isOfflineMode {
      currentPlayUrl = ""
      nextPreloadedPlayable = nil
      nextPreloadedUrl = ""
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

      Task { @MainActor in
        do {
          currentReplayGainValue = playable.replayGainTrackGain
          applyReplayGain()
          try await insertStreamPlayable(playable: playable)
          isPlaying = shouldPlaybackStart
          if self.isAutoCachePlayedItems, !playable.isRadio {
            self.playableDownloader.download(object: playable)
          }
          self.responder?.notifyItemPreparationFinished()
        } catch {
          self.responder?.notifyErrorOccurred(error: error)
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
    currentPreparedUrl = ""
    currentPlayUrl = ""
    nextPreloadedPlayable = nil
    nextPreloadedUrl = ""
    seekTimeWhenStarted = nil
    isPlaying = false
    playType = nil

    stopTimers()
    player?.stop()
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
      seekTimeWhenStarted = nil
      player?.pause()
      audioSessionHandler.configureBackgroundPlayback()
    }

    var asset: AVURLAsset?
    if let mimeType = playable.iOsCompatibleContentType {
      asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])
    } else {
      asset = AVURLAsset(url: url)
    }
    playInPlayer(asset: asset, queueType: queueType)
  }

  private func playInPlayer(
    asset: AVURLAsset?,
    queueType: BackendAudioQueueType
  ) {
    guard let asset = asset else {
      clearPlayer()
      return
    }

    switch queueType {
    case .play:
      currentPreparedUrl = asset.url.absoluteString
      player?.play(url: asset.url)
    case .queue:
      nextPreloadedUrl = asset.url.absoluteString
      player?.queue(url: asset.url)
    }
  }

  // MARK: - EQ Implementation

  func updateEqualizerEnabled(isEnabled: Bool) {
    isEqualizerEnabled = isEnabled
    os_log(.default, "Equalizer enabled: %s", isEnabled.description)
    applyEqualizerToActiveContent()
  }

  func updateEqualizerConfig(eqConfig: EqualizerConfig) {
    let oldConfig = currentEqualizerConfig
    currentEqualizerConfig = eqConfig
    os_log(
      .default,
      "Equalizer config changed from %s to %s",
      oldConfig.description,
      eqConfig.description
    )
    applyEqualizerToActiveContent()
  }

  private func applyEqualizerToActiveContent() {
    if isEqualizerEnabled {
      applyEqualizerConfig(eqConfig: currentEqualizerConfig)
    } else {
      applyEqualizerConfig(eqConfig: .off)
    }
    applyReplayGain()
  }

  private func setupEqualizerBands() {
    guard let equalizer else { return }

    for (index, frequency) in EqualizerConfig.frequencies.enumerated() {
      guard index < equalizer.bands.count else { break }

      let band = equalizer.bands[index]
      band.frequency = frequency
      band.bandwidth = 1.0
      band.filterType = .parametric
      band.gain = 0.0
      band.bypass = false
    }
  }

  private func applyEqualizerConfig(eqConfig: EqualizerConfig) {
    guard let equalizer else { return }

    // EQ band gains
    for (index, gain) in eqConfig.gains.enumerated() {
      guard index < equalizer.bands.count else { break }

      let band = equalizer.bands[index]

      band.filterType = .parametric
      band.bandwidth = 1.0
      band.gain = gain
      band.bypass = false
    }

    equalizerVolumeCompensation = isEqualizerEnabled ? eqConfig.compensatedVolume : 1.0

    os_log(.default, "   EQ Config '%s'", eqConfig.description)
    os_log(
      .default,
      "   EQ Gains: [%@] dB",
      eqConfig.gains.map { String(format: "%.1f", $0) }.joined(separator: ", ")
    )
    os_log(.default, "   EQ Gain Compensation: %.1f dB", eqConfig.gainCompensation)
    os_log(.default, "   EQ linear Volume Compensation: %.2f", eqConfig.compensatedVolume)
    os_log(.default, "   Active EQ linear Volume Compensation: %.2f", equalizerVolumeCompensation)
  }

  // MARK: - ReplayGain Implementation

  func updateReplayGainEnabled(isEnabled: Bool) {
    isReplayGainEnabled = isEnabled
    applyReplayGain()
  }

  private func applyReplayGain() {
    guard let replayGain = replayGainNode else { return }

    let eqCompensation = isEqualizerEnabled ? equalizerVolumeCompensation : 1.0

    if isReplayGainEnabled, currentReplayGainValue != 0.0 {
      // Convert dB to linear scale: gain = pow(10, dB / 20)
      let linearGain = pow(10.0, currentReplayGainValue / 20.0)
      replayGain.outputVolume = linearGain * eqCompensation
      os_log(
        .default,
        "ReplayGain: %.2f dB → %.3f linear gain (EQ Compensation: %.2f)",
        currentReplayGainValue,
        linearGain,
        eqCompensation
      )
    } else {
      replayGain.outputVolume = eqCompensation
      os_log(
        .default,
        "ReplayGain: disabled or no gain data (EQ Compensation: %.2f)",
        eqCompensation
      )
    }
  }
}

// MARK: AudioStreaming.AudioPlayerDelegate

extension BackendAudioPlayer: AudioStreaming.AudioPlayerDelegate {
  nonisolated func audioPlayerDidStartPlaying(
    player: AudioStreaming.AudioPlayer,
    with entryId: AudioStreaming.AudioEntryId
  ) {
    let entryID = entryId.id
    Task { @MainActor in
      didStartPlaying(url: entryID)
    }
  }

  @MainActor
  public func didStartPlaying(url: String) {
    if currentPreparedUrl == url {
      currentPreparedUrl = ""
      currentPlayUrl = url
      if shouldPlaybackStart {
        continuePlay()
      } else {
        pause()
      }

      if let seekTimeWhenStarted {
        player?.seek(to: seekTimeWhenStarted)
        self.seekTimeWhenStarted = nil
      }
    }
  }

  nonisolated func audioPlayerDidFinishBuffering(
    player: AudioStreaming.AudioPlayer,
    with entryId: AudioStreaming.AudioEntryId
  ) {}

  nonisolated func audioPlayerStateChanged(
    player: AudioStreaming.AudioPlayer,
    with newState: AudioStreaming.AudioPlayerState,
    previous: AudioStreaming.AudioPlayerState
  ) {}

  nonisolated func audioPlayerDidFinishPlaying(
    player: AudioStreaming.AudioPlayer,
    entryId: AudioStreaming.AudioEntryId,
    stopReason: AudioStreaming.AudioPlayerStopReason,
    progress: Double,
    duration: Double
  ) {
    let entryID = entryId.id
    Task { @MainActor in
      if self.currentPlayUrl == entryID {
        self.currentPlayUrl = ""
        self.itemFinishedPlaying()
      }
    }
  }

  nonisolated func audioPlayerUnexpectedError(
    player: AudioStreaming.AudioPlayer,
    error: AudioStreaming.AudioPlayerError
  ) {
    Task { @MainActor in
      self.handleError(error: error)
    }
  }

  nonisolated func audioPlayerDidCancel(
    player: AudioStreaming.AudioPlayer,
    queuedItems: [AudioStreaming.AudioEntryId]
  ) {
    Task { @MainActor in
      self.currentPlayUrl = ""
    }
  }

  nonisolated func audioPlayerDidReadMetadata(
    player: AudioStreaming.AudioPlayer,
    metadata: [String: String]
  ) {}
}
