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

public enum PlayType {
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
  private let getPlayableDownloaderCB: GetPlayableDownloadManagerCallback
  private let cacheProxy: PlayableFileCachable
  private let getBackendApiCB: GetBackendApiCallback
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
  
  // Playback watchdog - detects stuck playback
  private var lastKnownElapsedTime: Double = 0.0
  private var stuckPlaybackCheckCount: Int = 0
  private let maxStuckPlaybackChecks: Int = 3  // After 3 seconds of no progress, attempt recovery
  
  // Startup watchdog - detects when playback fails to start
  private var startupWatchdogTimer: Timer?
  private var expectedPlaybackStartTime: Date?
  
  // Pending asset to play when user presses play (used when autoStartPlayback is false)
  private var pendingPlayAsset: AVURLAsset?
  
  // Track the currently playing playable (for switching from stream to cache on seek)
  private var currentPlayable: AbstractPlayable?

  private var player: AudioStreamingPlayer?
  private var equalizer: AVAudioUnitEQ?
  private var replayGainNode: AVAudioMixerNode?
  public private(set) var audioAnalyzer: AudioAnalyzer

  // ReplayGain Settings
  private var isReplayGainEnabled: Bool = true
  private var currentReplayGainValue: Float = 0.0 // ReplayGain in dB
  private var replayGainPreamp: Int = 0 // Preamp in dB (-7 to +7)
  // EQ Settings
  private var equalizerVolumeCompensation: Float = 1.0
  private var isEqualizerEnabled: Bool = true
  private var currentEqualizerSetting: EqualizerSetting = .off

  public var isOfflineMode: Bool = false
  public var isAutoCachePlayedItems: Bool = true
  public var nextPlayablePreloadCB: NextPlayablePreloadCallback?
  public var triggerReinsertPlayableCB: TriggerReinsertPlayableCallback?
  public private(set) var isPlaying: Bool = false
  public private(set) var isErrorOccurred: Bool = false
  public private(set) var playType: PlayType?
  private var perloadedPlayType: PlayType?
  public private(set) var activeStreamingBitrate: StreamingMaxBitratePreference?
  private var perloadedStreamingBitrate: StreamingMaxBitratePreference?
  public private(set) var activeTranscodingFormat: StreamingFormatPreference?
  private var preloadTranscodingFormat: StreamingFormatPreference?
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

  public private(set) var streamingTranscodings = StreamingTranscodings()
  public func setStreamingTranscodings(to: StreamingTranscodings) {
    os_log(
      .default,
      "Update Streaming Transcoding: <Wifi: %s, Cellular: %s> -> <Wifi: %s, Cellular: %s> (for next stream)",
      streamingTranscodings.wifi.description,
      streamingTranscodings.cellular.description,
      to.wifi.description,
      to.cellular.description
    )
    // Update the stored bitrates
    streamingTranscodings = to
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
    getBackendApiCB: @escaping GetBackendApiCallback,
    networkMonitor: NetworkMonitorFacade,
    getPlayableDownloaderCB: @escaping GetPlayableDownloadManagerCallback,
    cacheProxy: PlayableFileCachable,
    userStatistics: UserStatistics
  ) {
    self.createAudioStreamingPlayerCB = createAudioStreamingPlayerCB
    self.audioSessionHandler = audioSessionHandler
    self.getBackendApiCB = getBackendApiCB
    self.networkMonitor = networkMonitor
    self.eventLogger = eventLogger
    self.getPlayableDownloaderCB = getPlayableDownloaderCB
    self.cacheProxy = cacheProxy
    self.userStatistics = userStatistics
    self.audioAnalyzer = AudioAnalyzer()

    super.init()

    initAudioStreamingPlayerAndNodes()
  }

  private func startTimers() {
    stopTimers()
    
    // Reset watchdog state
    lastKnownElapsedTime = elapsedTime
    stuckPlaybackCheckCount = 0
    
    // Use DispatchQueue timers instead of creating Tasks every tick
    // This prevents Task accumulation when main thread is busy
    timerElapsedTimeInterval = Timer.scheduledTimer(
      withTimeInterval: updateElapsedTimeInterval.seconds,
      repeats: true
    ) { [weak self] _ in
      // Timer already fires on main thread, no need to dispatch again
      guard let self else { return }
      self.checkForPreloadNextPlayerItem()
      self.checkForStuckPlayback()
      self.responder?.didElapsedTimeChange()
    }
    timerLyricsTimeInterval = Timer.scheduledTimer(
      withTimeInterval: updateLyricsTimeInterval.seconds,
      repeats: true
    ) { [weak self] _ in
      guard let self else { return }
      let cmTime = CMTime(value: Int64(self.elapsedTime * 1_000), timescale: 1_000)
      self.responder?.didLyricsTimeChange(time: cmTime)
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
              // AVPlayer handles seeking on streamed content natively - no download needed
            } catch {
              self.nextPreloadedPlayable = nil
              self.eventLogger.report(topic: "Player", error: error)
            }
          }
        }
      }
    }
  }
  
  /// Watchdog to detect and recover from stuck playback
  /// This handles cases where the UI shows "playing" but audio isn't actually progressing
  private func checkForStuckPlayback() {
    // Only check if we think we should be playing
    guard isPlaying else {
      stuckPlaybackCheckCount = 0
      lastKnownElapsedTime = 0
      return
    }
    
    let currentElapsed = elapsedTime
    let playerState = player?.getState()
    
    // Check if elapsed time is stuck (either at 0 or not advancing)
    let isStuck = abs(currentElapsed - lastKnownElapsedTime) < 0.1
    
    if isStuck {
      // Elapsed time hasn't changed significantly
      stuckPlaybackCheckCount += 1
      os_log(.debug, "Playback watchdog: no progress detected (%d/%d), elapsed=%f, state=%s", 
             stuckPlaybackCheckCount, maxStuckPlaybackChecks, currentElapsed, String(describing: playerState))
      
      if stuckPlaybackCheckCount >= maxStuckPlaybackChecks {
        os_log(.default, "Playback watchdog: attempting recovery - elapsed time stuck at %f", currentElapsed)
        stuckPlaybackCheckCount = 0
        
        os_log(.debug, "Playback watchdog: player state is %s, currentPlayUrl=%s", 
               String(describing: playerState), currentPlayUrl.isEmpty ? "(empty)" : "(set)")
        
        if playerState == .paused || playerState == .stopped {
          // Player is paused/stopped but we think it should be playing - resume it
          os_log(.default, "Playback watchdog: resuming paused/stopped player")
          player?.resume()
          player?.rate = Float(userDefinedPlaybackRate.asDouble)
        } else if playerState == .bufferring {
          // Still buffering - reset counter and wait longer
          os_log(.debug, "Playback watchdog: player is buffering, waiting...")
          stuckPlaybackCheckCount = -3  // Give extra time for buffering
        } else if playerState == .playing && currentElapsed == 0 {
          // Player thinks it's playing but elapsed time is 0 - try to restart
          os_log(.default, "Playback watchdog: player state is playing but elapsed=0, attempting restart")
          if let playable = currentPlayable {
            // Re-request playback
            player?.stop()
            requestToPlay(playable: playable, playbackRate: userDefinedPlaybackRate, autoStartPlayback: true)
          }
        }
      }
    } else {
      // Playback is progressing normally
      stuckPlaybackCheckCount = 0
    }
    
    lastKnownElapsedTime = currentElapsed
  }
  
  /// Starts a watchdog timer that monitors if playback actually begins
  /// This catches cases where the didStartPlaying callback never fires
  private func startStartupWatchdog() {
    stopStartupWatchdog()
    expectedPlaybackStartTime = Date()
    
    startupWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.checkStartupWatchdog()
    }
  }
  
  private func stopStartupWatchdog() {
    startupWatchdogTimer?.invalidate()
    startupWatchdogTimer = nil
    expectedPlaybackStartTime = nil
  }
  
  private func checkStartupWatchdog() {
    // Only check if we expected playback to start and timers aren't running
    guard isPlaying, timerElapsedTimeInterval == nil else {
      os_log(.debug, "Startup watchdog: conditions not met (isPlaying=%s, timersRunning=%s)", 
             isPlaying.description, (timerElapsedTimeInterval != nil).description)
      return
    }
    
    let playerState = player?.getState()
    os_log(.default, "Startup watchdog: playback expected but timers not running! state=%s, elapsed=%f", 
           String(describing: playerState), elapsedTime)
    
    // Timers should be running but aren't - this means didStartPlaying callback likely failed
    // Force start the timers and attempt recovery
    if playerState == .playing || playerState == .bufferring {
      os_log(.default, "Startup watchdog: player seems active, forcing timer start and continuePlay")
      continuePlay()
    } else if playerState == .paused || playerState == .stopped {
      os_log(.default, "Startup watchdog: player is paused/stopped, attempting to resume")
      player?.resume()
      player?.rate = Float(userDefinedPlaybackRate.asDouble)
      startTimers()
    } else if let playable = currentPlayable {
      os_log(.default, "Startup watchdog: unknown state, re-requesting playback")
      // Something went wrong - try re-requesting playback
      requestToPlay(playable: playable, playbackRate: userDefinedPlaybackRate, autoStartPlayback: true)
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
    activeStreamingBitrate = nil
    perloadedStreamingBitrate = nil
    activeTranscodingFormat = nil
    preloadTranscodingFormat = nil
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
    
    // Playback is starting - stop the startup watchdog
    stopStartupWatchdog()
    
    // Reset watchdog state since we're actively starting/continuing playback
    stuckPlaybackCheckCount = 0
    lastKnownElapsedTime = elapsedTime
    
    // If there's a pending asset (from next/prev while paused), play it now
    if let pendingAsset = pendingPlayAsset {
      pendingPlayAsset = nil
      player?.play(url: pendingAsset.url)
    } else {
      player?.resume()
    }
    
    startTimers()
    player?.rate = Float(userDefinedPlaybackRate.asDouble)
    audioAnalyzer.play()
  }

  func pause() {
    isPlaying = false
    stopStartupWatchdog()
    player?.pause()
    stopTimers()
    audioAnalyzer.stop()
  }

  func stop() {
    isPlaying = false
    pendingPlayAsset = nil
    currentPlayable = nil
    stopStartupWatchdog()
    
    clearPlayer()
    audioAnalyzer.stop()
  }

  func setPlaybackRate(_ newValue: PlaybackRate) {
    userDefinedPlaybackRate = newValue
    player?.rate = Float(newValue.asDouble)
  }

  func seek(toSecond: Double) {
    let state = player?.getState()
    os_log(
      .debug,
      "Seek to %f - currentPlayUrl: '%s', state: %s, playType: %s",
      toSecond,
      currentPlayUrl,
      String(describing: state),
      String(describing: playType)
    )
    
    // If currently streaming but song is now cached, switch to cached version for seeking
    if playType == .stream,
       let playable = currentPlayable,
       playable.isCached,
       let relFilePath = playable.relFilePath,
       fileManager.fileExits(relFilePath: relFilePath) {
      os_log(.debug, "Song now cached - switching from stream to cache for seeking to %f", toSecond)
      let wasPlaying = isPlaying
      
      // Match the exact flow from handleRequest for cached files
      currentPlayUrl = ""
      nextPreloadedPlayable = nil
      nextPreloadedUrl = ""
      activeStreamingBitrate = nil
      perloadedStreamingBitrate = nil
      activeTranscodingFormat = nil
      preloadTranscodingFormat = nil
      
      // Set isAutoStartPlayback so shouldPlaybackStart returns correct value
      isAutoStartPlayback = true
      
      currentReplayGainValue = playable.replayGainTrackGain
      applyReplayGain()
      
      // Use seekTo parameter to pass the seek position
      insertCachedPlayable(playable: playable, autoStartPlayback: true, seekTo: toSecond)
      isPlaying = true
      
      // Safety net: if didStartPlaying callback doesn't fire or URL doesn't match,
      // perform the seek after a delay as backup
      let seekPosition = toSecond
      let shouldPause = !wasPlaying
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        guard let self else { return }
        // Only seek if it wasn't already done (seekTimeWhenStarted would be nil if processed)
        if self.seekTimeWhenStarted != nil {
          os_log(.debug, "Safety net: Executing backup seek to %f", seekPosition)
          self.player?.seek(to: seekPosition)
          self.seekTimeWhenStarted = nil
        }
        if shouldPause {
          self.pause()
        }
      }
      
      return
    }
    
    if currentPlayUrl != "",
       state == .playing || state == .paused || state == .bufferring {
      seekTimeWhenStarted = nil
      player?.seek(to: toSecond)
      os_log(.debug, "Seek executed via player")
    } else {
      seekTimeWhenStarted = toSecond
      os_log(.debug, "Seek deferred to seekTimeWhenStarted")
    }
  }
  
  private func clearPlayerState() {
    currentPreparedUrl = ""
    currentPlayUrl = ""
    nextPreloadedPlayable = nil
    nextPreloadedUrl = ""
    playType = nil
    perloadedPlayType = nil
    activeStreamingBitrate = nil
    perloadedStreamingBitrate = nil
    activeTranscodingFormat = nil
    preloadTranscodingFormat = nil
  }

  private func restartPlayer() {
    // Remove audio tap before deallocating the old nodes
    audioAnalyzer.removeTap()
    player = nil
    initAudioStreamingPlayerAndNodes()
  }

  private func initAudioStreamingPlayerAndNodes() {
    guard player == nil else { return }
    player = createAudioStreamingPlayerCB()

    equalizer = AVAudioUnitEQ(numberOfBands: 10)
    replayGainNode = AVAudioMixerNode()
    audioAnalyzer = AudioAnalyzer()

    guard let player,
          let eq = equalizer,
          let replayGain = replayGainNode
    else { return }

    player.volume = volumePlayer
    player.delegate = self

    player.attach(nodes: [eq, replayGain])

    audioAnalyzer.install(on: equalizer!)

    setupEqualizerBands()
    applyEqualizerSetting(eqSetting: currentEqualizerSetting)
    applyReplayGain()
    os_log(.debug, "Player setup completed with EQ and ReplayGain support")
  }

  var shouldPlaybackStart: Bool {
    (!isErrorOccurred && isAutoStartPlayback) || (isErrorOccurred && wasPlayingBeforeErrorOccurred)
  }

  func requestToPlay(
    playable: AbstractPlayable,
    playbackRate: PlaybackRate,
    autoStartPlayback: Bool
  ) {
    // Don't clean up on every skip - let the periodic cleanup handle it
    // This prevents excessive Core Data fetches during rapid skipping
    
    userDefinedPlaybackRate = playbackRate
    player?.rate = Float(userDefinedPlaybackRate.asDouble)
    isAutoStartPlayback = autoStartPlayback
    handleRequest(playable: playable)
  }

  private func handleRequest(playable: AbstractPlayable) {
    currentPlayable = playable
    
    if isPreviousPlaylableFinshed, let nextPreloadedPlayable = nextPreloadedPlayable,
       nextPreloadedPlayable == playable {
      // Do nothing next preloaded playable has already been queued to player
      os_log(.default, "Play Preloaded: %s", nextPreloadedPlayable.displayString)
      currentPreparedUrl = ""
      currentPlayUrl = nextPreloadedUrl
      os_log(.debug, "Preloaded - currentPlayUrl set to: %s", nextPreloadedUrl.prefix(80).description)
      playType = perloadedPlayType
      perloadedPlayType = nil
      activeStreamingBitrate = perloadedStreamingBitrate
      perloadedStreamingBitrate = nil
      activeTranscodingFormat = preloadTranscodingFormat
      preloadTranscodingFormat = nil
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
      activeStreamingBitrate = nil
      perloadedStreamingBitrate = nil
      activeTranscodingFormat = nil
      preloadTranscodingFormat = nil
      guard playable.isPlayableOniOS else {
        reactToIncompatibleContentType(
          contentType: playable.fileContentType ?? "",
          playableDisplayTitle: playable.displayString
        )
        return
      }
      currentReplayGainValue = playable.replayGainTrackGain
      applyReplayGain()
      insertCachedPlayable(playable: playable, autoStartPlayback: shouldPlaybackStart)
      isPlaying = shouldPlaybackStart
      if shouldPlaybackStart {
        startStartupWatchdog()
      }
      responder?.notifyItemPreparationFinished()
    } else if !isOfflineMode {
      currentPlayUrl = ""
      nextPreloadedPlayable = nil
      nextPreloadedUrl = ""
      activeStreamingBitrate = nil
      perloadedStreamingBitrate = nil
      activeTranscodingFormat = nil
      preloadTranscodingFormat = nil
      guard playable.isPlayableOniOS || streamingTranscodings
        .isTranscodingActive(networkMonitor: networkMonitor) else {
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
          try await insertStreamPlayable(playable: playable, autoStartPlayback: self.shouldPlaybackStart)
          self.isPlaying = self.shouldPlaybackStart
          if self.shouldPlaybackStart {
            self.startStartupWatchdog()
          }
          
          // AVPlayer handles seeking on streamed content natively - no download needed
          
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
    pendingPlayAsset = nil
    playType = nil
    perloadedPlayType = nil
    activeStreamingBitrate = nil
    perloadedStreamingBitrate = nil
    activeTranscodingFormat = nil
    preloadTranscodingFormat = nil
    seekTimeWhenStarted = nil
    isPlaying = false
    playType = nil

    stopTimers()
    audioAnalyzer.stop()
    player?.stop()
  }

  private func insertCachedPlayable(
    playable: AbstractPlayable,
    queueType: BackendAudioQueueType = .play,
    autoStartPlayback: Bool = true,
    seekTo: Double? = nil
  ) {
    guard let fileURL = cacheProxy.getFileURL(forPlayable: playable) else {
      return
    }
    if queueType == .play {
      playType = .cache
      perloadedPlayType = nil
      os_log(.default, "Play Cache: %s (%s)", playable.displayString, fileURL.absoluteString)
    } else {
      perloadedPlayType = .cache
      os_log(.default, "Insert Cache: %s (%s)", playable.displayString, fileURL.absoluteString)
    }
    if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
    insert(playable: playable, withUrl: fileURL, queueType: queueType, autoStartPlayback: autoStartPlayback, seekTo: seekTo)
  }

  @MainActor
  private func insertStreamPlayable(
    playable: AbstractPlayable,
    queueType: BackendAudioQueueType = .play,
    autoStartPlayback: Bool = true
  ) async throws {
    let streamingMaxBitrate = streamingMaxBitrates.getActive(networkMonitor: networkMonitor)
    let streamingTranscodingFormat = streamingTranscodings.getActive(networkMonitor: networkMonitor)
    @MainActor
    func provideUrl() async throws -> URL {
      if let radio = playable.asRadio {
        guard let streamUrlString = radio.url,
              let streamUrl = URL(string: streamUrlString)
        else {
          throw BackendError.invalidUrl
        }
        playType = .stream
        return streamUrl
      } else {
        if queueType == .play {
          playType = .stream
          perloadedPlayType = nil
          activeStreamingBitrate = streamingMaxBitrate
          perloadedStreamingBitrate = nil
          activeTranscodingFormat = streamingTranscodingFormat
          preloadTranscodingFormat = nil
        } else {
          perloadedPlayType = .stream
          perloadedStreamingBitrate = streamingMaxBitrate
          preloadTranscodingFormat = streamingTranscodingFormat
        }
        guard let accountInfo = playable.account?.info else {
          throw BackendError.noCredentials
        }
        return try await getBackendApiCB(accountInfo).generateUrl(
          forStreamingPlayable: playable.info,
          maxBitrate: streamingMaxBitrate,
          formatPreference: streamingTranscodingFormat
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
    if playable.isSong { userStatistics.playedSong(isPlayedFromCache: false) }
    insert(
      playable: playable,
      withUrl: streamUrl,
      streamingMaxBitrate: streamingMaxBitrate,
      queueType: queueType,
      autoStartPlayback: autoStartPlayback
    )
  }

  private func insert(
    playable: AbstractPlayable,
    withUrl url: URL,
    streamingMaxBitrate: StreamingMaxBitratePreference = .noLimit,
    queueType: BackendAudioQueueType,
    autoStartPlayback: Bool = true,
    seekTo: Double? = nil
  ) {
    if queueType == .play {
      seekTimeWhenStarted = seekTo  // Set seek time instead of clearing (nil if not provided)
      player?.pause()
      audioSessionHandler.configureBackgroundPlayback()
    }

    var asset: AVURLAsset?
    if let mimeType = playable.iOsCompatibleContentType {
      asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])
    } else {
      asset = AVURLAsset(url: url)
    }
    playInPlayer(asset: asset, queueType: queueType, autoStartPlayback: autoStartPlayback)
  }

  private func playInPlayer(
    asset: AVURLAsset?,
    queueType: BackendAudioQueueType,
    autoStartPlayback: Bool = true
  ) {
    guard let asset = asset else {
      clearPlayer()
      return
    }

    switch queueType {
    case .play:
      currentPreparedUrl = asset.url.absoluteString
      
      if !autoStartPlayback {
        // Don't start audio at all - just store the asset for when user presses play
        pendingPlayAsset = asset
        // Stop any currently playing audio
        player?.stop()
      } else {
        // Clear any pending asset since we're playing now
        pendingPlayAsset = nil
        player?.play(url: asset.url)
      }
    case .queue:
      nextPreloadedUrl = asset.url.absoluteString
      player?.queue(url: asset.url)
    }
  }

  // MARK: - EQ Implementation

  func updateEqualizerEnabled(isEnabled: Bool) {
    isEqualizerEnabled = isEnabled
    os_log(.debug, "Equalizer enabled: %s", isEnabled.description)
    applyEqualizerToActiveContent()
  }

  func updateEqualizerSetting(eqSetting: EqualizerSetting) {
    let oldSetting = currentEqualizerSetting
    currentEqualizerSetting = eqSetting
    os_log(
      .debug,
      "Equalizer changed from %s to %s",
      oldSetting.description,
      eqSetting.description
    )
    applyEqualizerToActiveContent()
  }

  private func applyEqualizerToActiveContent() {
    if isEqualizerEnabled {
      applyEqualizerSetting(eqSetting: currentEqualizerSetting)
    } else {
      applyEqualizerSetting(eqSetting: .off)
    }
    applyReplayGain()
  }

  private func setupEqualizerBands() {
    guard let equalizer else { return }

    for (index, frequency) in EqualizerSetting.frequencies.enumerated() {
      guard index < equalizer.bands.count else { break }

      let band = equalizer.bands[index]
      band.frequency = frequency
      band.bandwidth = 1.0
      band.filterType = .parametric
      band.gain = 0.0
      band.bypass = false
    }
  }

  private func applyEqualizerSetting(eqSetting: EqualizerSetting) {
    guard let equalizer else { return }

    // EQ band gains
    for (index, gain) in eqSetting.gains.enumerated() {
      guard index < equalizer.bands.count else { break }

      let band = equalizer.bands[index]

      band.filterType = .parametric
      band.bandwidth = 1.0
      band.gain = gain
      band.bypass = false
    }

    equalizerVolumeCompensation = isEqualizerEnabled ? eqSetting.compensatedVolume : 1.0

    os_log(.debug, "   EQ '%s'", eqSetting.description)
    os_log(
      .debug,
      "   EQ Gains: [%@] dB",
      eqSetting.gains.map { String(format: "%.1f", $0) }.joined(separator: ", ")
    )
    os_log(.debug, "   EQ Gain Compensation: %.1f dB", eqSetting.gainCompensation)
    os_log(.debug, "   EQ linear Volume Compensation: %.2f", eqSetting.compensatedVolume)
    os_log(.debug, "   Active EQ linear Volume Compensation: %.2f", equalizerVolumeCompensation)
  }

  // MARK: - ReplayGain Implementation

  func updateReplayGainEnabled(isEnabled: Bool) {
    isReplayGainEnabled = isEnabled
    applyReplayGain()
  }
  
  func updateReplayGainPreamp(preamp: Int) {
    replayGainPreamp = preamp
    applyReplayGain()
  }
  private func applyReplayGain() {
    guard let replayGain = replayGainNode else { return }

    let eqCompensation = isEqualizerEnabled ? equalizerVolumeCompensation : 1.0

    if isReplayGainEnabled, currentReplayGainValue != 0.0 {
      // Apply track gain + preamp offset
      let totalGain = currentReplayGainValue + Float(replayGainPreamp)
      // Convert dB to linear scale: gain = pow(10, dB / 20)
      let linearGain = pow(10.0, totalGain / 20.0)
      replayGain.outputVolume = linearGain * eqCompensation
      os_log(
        .debug,
        "ReplayGain: %.2f dB + %d dB preamp = %.2f dB → %.3f linear gain (EQ Compensation: %.2f)",
        currentReplayGainValue,
        replayGainPreamp,
        totalGain,
        linearGain,
        eqCompensation
      )
    } else {
      replayGain.outputVolume = eqCompensation
      os_log(
        .debug,
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
    // Check for exact match
    var isMatch = currentPreparedUrl == url
    
    // For file URLs, also check if the filenames match (URLs may have different encoding/format)
    if !isMatch, currentPreparedUrl.hasPrefix("file://"), url.hasPrefix("file://") {
      let preparedFilename = URL(string: currentPreparedUrl)?.lastPathComponent
      let receivedFilename = URL(string: url)?.lastPathComponent
      if let pf = preparedFilename, let rf = receivedFilename, pf == rf {
        isMatch = true
        os_log(.debug, "File URL match by filename: %s", pf)
      }
    }
    
    // For streaming URLs, check if the base URLs match (ignoring query parameters that might differ)
    if !isMatch, !currentPreparedUrl.hasPrefix("file://"), !url.hasPrefix("file://") {
      if let preparedURL = URL(string: currentPreparedUrl),
         let receivedURL = URL(string: url) {
        // Compare host and path, ignoring query parameters
        if preparedURL.host == receivedURL.host && preparedURL.path == receivedURL.path {
          isMatch = true
          os_log(.debug, "Streaming URL match by host+path: %s%s", preparedURL.host ?? "", preparedURL.path)
        }
      }
    }
    
    os_log(
      .debug,
      "didStartPlaying called - url: %s, currentPreparedUrl: %s, match: %s",
      url.prefix(80).description,
      currentPreparedUrl.prefix(80).description,
      isMatch.description
    )
    if isMatch {
      if let sampleRate = player?.mainMixerNode.outputFormat(forBus: 0).sampleRate {
        audioAnalyzer.playing(sampleRate: Float(sampleRate))
      }

      currentPreparedUrl = ""
      currentPlayUrl = url
      os_log(.debug, "currentPlayUrl set to: %s", url.prefix(80).description)
      if shouldPlaybackStart {
        continuePlay()
        audioAnalyzer.play()
      } else {
        pause()
        audioAnalyzer.stop()
      }

      if let seekTimeWhenStarted {
        os_log(.debug, "Executing deferred seek to: %f", seekTimeWhenStarted)
        player?.seek(to: seekTimeWhenStarted)
        self.seekTimeWhenStarted = nil
      }
    } else {
      os_log(.debug, "didStartPlaying: URL mismatch - currentPlayUrl NOT updated!")
      
      // Fallback: Process the playback anyway if we have a prepared URL pending
      // This handles cases where the URL format differs between what we set and what we receive
      if !currentPreparedUrl.isEmpty {
        os_log(.debug, "Fallback: Processing URL despite mismatch (prepared URL was pending)")
        currentPreparedUrl = ""
        currentPlayUrl = url
        
        if let sampleRate = player?.mainMixerNode.outputFormat(forBus: 0).sampleRate {
          audioAnalyzer.playing(sampleRate: Float(sampleRate))
        }
        
        if shouldPlaybackStart {
          continuePlay()
          audioAnalyzer.play()
        } else {
          pause()
          audioAnalyzer.stop()
        }
        
        if let seekTimeWhenStarted {
          os_log(.debug, "Fallback: Executing deferred seek to: %f", seekTimeWhenStarted)
          player?.seek(to: seekTimeWhenStarted)
          self.seekTimeWhenStarted = nil
        }
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
