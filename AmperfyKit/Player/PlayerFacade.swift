//
//  PlayerFacade.swift
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

// MARK: - StreamingMaxBitrates

@MainActor
public struct StreamingMaxBitrates {
  public var wifi: StreamingMaxBitratePreference = .noLimit
  public var cellular: StreamingMaxBitratePreference = .noLimit

  public init(wifi: StreamingMaxBitratePreference, cellular: StreamingMaxBitratePreference) {
    self.wifi = wifi
    self.cellular = cellular
  }

  public init() {
    self.wifi = .noLimit
    self.cellular = .noLimit
  }

  public func getActive(networkMonitor: NetworkMonitorFacade) -> StreamingMaxBitratePreference {
    if networkMonitor.isWifiOrEthernet {
      return wifi
    } else {
      return cellular
    }
  }
}

// MARK: - StreamingTranscodings

@MainActor
public struct StreamingTranscodings {
  public var wifi: StreamingFormatPreference = .serverConfig
  public var cellular: StreamingFormatPreference = .serverConfig

  public init(wifi: StreamingFormatPreference, cellular: StreamingFormatPreference) {
    self.wifi = wifi
    self.cellular = cellular
  }

  public init() {
    self.wifi = .serverConfig
    self.cellular = .serverConfig
  }

  public func getActive(networkMonitor: NetworkMonitorFacade) -> StreamingFormatPreference {
    if networkMonitor.isWifiOrEthernet {
      return wifi
    } else {
      return cellular
    }
  }

  public func isTranscodingActive(networkMonitor: NetworkMonitorFacade) -> Bool {
    if networkMonitor.isCellular {
      if cellular != .raw {
        return true
      }
    } else {
      if wifi != .raw {
        return true
      }
    }
    return false
  }
}

// MARK: - PlayContext

public struct PlayContext {
  let index: Int
  let name: String
  let playables: [AbstractPlayable]
  let type: PlayerMode
  public var isKeepIndexDuringShuffle: Bool = false

  public init() {
    self.name = ""
    self.index = 0
    self.playables = []
    self.type = .music
  }

  public init(containable: PlayableContainable) {
    self.name = containable.name
    self.index = 0
    self.playables = containable.playables
    self.type = containable.playContextType
    containable.playedViaContext()
  }

  public init(name: String, index: Int = 0, playables: [AbstractPlayable]) {
    self.name = name
    self.index = index
    self.playables = playables
    self.type = .music
  }

  public init(name: String, type: PlayerMode, index: Int = 0, playables: [AbstractPlayable]) {
    self.name = name
    self.index = index
    self.playables = playables
    self.type = type
  }

  public init(containable: PlayableContainable, index: Int = 0, playables: [AbstractPlayable]) {
    self.name = containable.name
    self.index = index
    self.playables = playables
    self.type = containable.playContextType
    containable.playedViaContext()
  }

  func getActivePlayable() -> AbstractPlayable? {
    guard !playables.isEmpty, index < playables.count else { return nil }
    return playables[index]
  }

  public func getWithShuffledIndex() -> PlayContext {
    guard !isKeepIndexDuringShuffle else { return self }
    return PlayContext(
      name: name,
      index: (playables.count < 2) ? 0 : Int.random(in: 0 ... playables.count - 1),
      playables: playables
    )
  }
}

// MARK: - PlayerFacade

@MainActor
public protocol PlayerFacade {
  var prevQueueCount: Int { get }
  func getPrevQueueItems(from: Int, to: Int?) -> [AbstractPlayable]
  func getAllPrevQueueItems() -> [AbstractPlayable]
  var userQueueCount: Int { get }
  func getUserQueueItems(from: Int, to: Int?) -> [AbstractPlayable]
  func getAllUserQueueItems() -> [AbstractPlayable]
  var nextQueueCount: Int { get }
  func getNextQueueItems(from: Int, to: Int?) -> [AbstractPlayable]
  func getAllNextQueueItems() -> [AbstractPlayable]

  var totalPlayDuration: Int { get }
  var remainingPlayDuration: Int { get }
  var volume: Float { get set }
  var isPlaying: Bool { get }
  func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable?
  var currentlyPlaying: AbstractPlayable? { get }
  var currentMusicItem: AbstractPlayable? { get }
  var currentPodcastItem: AbstractPlayable? { get }
  var contextName: String { get }
  var elapsedTime: Double { get }
  var duration: Double { get }
  var isShuffle: Bool { get }
  func toggleShuffle()
  var playbackRate: PlaybackRate { get }
  func setPlaybackRate(_: PlaybackRate)
  var repeatMode: RepeatMode { get }
  func setRepeatMode(_: RepeatMode)
  var isOfflineMode: Bool { get set }
  var isShouldPauseAfterFinishedPlaying: Bool { get set }
  var isAutoCachePlayedItems: Bool { get set }
  var isPopupBarAllowedToHide: Bool { get }
  var musicItemCount: Int { get }
  var podcastItemCount: Int { get }
  var playerMode: PlayerMode { get }
  var playType: PlayType? { get }
  var activeStreamingBitrate: StreamingMaxBitratePreference? { get }
  var activeTranscodingFormat: StreamingFormatPreference? { get }
  func setPlayerMode(_ newValue: PlayerMode)
  var streamingMaxBitrates: StreamingMaxBitrates { get }
  func setStreamingMaxBitrates(to: StreamingMaxBitrates)
  var streamingTranscodings: StreamingTranscodings { get }
  func setStreamingTranscodings(to: StreamingTranscodings)

  func logout(account: Account)

  func insertContextQueue(playables: [AbstractPlayable])
  func appendContextQueue(playables: [AbstractPlayable])
  func insertUserQueue(playables: [AbstractPlayable])
  func appendUserQueue(playables: [AbstractPlayable])
  func insertPodcastQueue(playables: [AbstractPlayable])
  func appendPodcastQueue(playables: [AbstractPlayable])
  func removePlayable(at: PlayerIndex)
  func movePlayable(from: PlayerIndex, to: PlayerIndex)
  func clearUserQueue()
  func clearContextQueue()
  func clearQueues()

  func play()
  func play(context: PlayContext)
  func playShuffled(context: PlayContext)
  func play(playerIndex: PlayerIndex)
  func pause()
  func togglePlayPause()
  func stop()
  func playPrevious()
  func playPreviousOrReplay()
  func playNext()
  func skipForward(interval: Double)
  func skipBackward(interval: Double)
  func seek(toSecond: Double)

  var audioAnalyzer: AudioAnalyzer { get }

  func addNotifier(notifier: MusicPlayable)

  func updateEqualizerEnabled(isEnabled: Bool)
  func updateEqualizerSetting(eqSetting: EqualizerSetting)
  func updateReplayGainEnabled(isEnabled: Bool)
}

extension PlayerFacade {
  public var maxSongsToAddOnce: Int { 500 }
  public var skipForwardPodcastInterval: Double { 30.0 }
  public var skipBackwardPodcastInterval: Double { 15.0 }
  public var skipForwardMusicInterval: Double { 10.0 }
  public var skipBackwardMusicInterval: Double { 10.0 }

  public var skipForwardInterval: Double {
    switch playerMode {
    case .music:
      return skipForwardMusicInterval
    case .podcast:
      return skipForwardPodcastInterval
    }
  }

  public var skipForwardIcon: UIImage {
    switch playerMode {
    case .music:
      return .skipForward10
    case .podcast:
      return .skipForward30
    }
  }

  public var skipBackwardInterval: Double {
    switch playerMode {
    case .music:
      return skipBackwardMusicInterval
    case .podcast:
      return skipBackwardPodcastInterval
    }
  }

  public var skipBackwardIcon: UIImage {
    switch playerMode {
    case .music:
      return .skipBackward10
    case .podcast:
      return .skipBackward15
    }
  }

  public var isSkipAvailable: Bool {
    if let currentlyPlaying = currentlyPlaying,
       currentlyPlaying.isRadio {
      return false
    } else {
      return true
    }
  }

  public var isStopInsteadOfPause: Bool {
    if let currentlyPlaying = currentlyPlaying,
       currentlyPlaying.isRadio {
      return true
    } else {
      return false
    }
  }
}

// MARK: - PlayerFacadeImpl

@MainActor
class PlayerFacadeImpl: PlayerFacade {
  private var playerStatus: PlayerStatusPersistent
  private var queueHandler: PlayQueueHandler
  private let backendAudioPlayer: BackendAudioPlayer
  private let musicPlayer: AudioPlayer
  private let userStatistics: UserStatistics

  init(
    playerStatus: PlayerStatusPersistent,
    queueHandler: PlayQueueHandler,
    musicPlayer: AudioPlayer,
    library: LibraryStorage,
    backendAudioPlayer: BackendAudioPlayer,
    userStatistics: UserStatistics
  ) {
    self.playerStatus = playerStatus
    self.queueHandler = queueHandler
    self.backendAudioPlayer = backendAudioPlayer
    self.musicPlayer = musicPlayer
    self.userStatistics = userStatistics
  }

  var prevQueueCount: Int {
    queueHandler.prevQueueCount
  }

  func getPrevQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    queueHandler.getPrevQueueItems(from: from, to: to)
  }

  func getAllPrevQueueItems() -> [AbstractPlayable] {
    queueHandler.getAllPrevQueueItems()
  }

  var userQueueCount: Int {
    queueHandler.userQueueCount
  }

  func getUserQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    queueHandler.getUserQueueItems(from: from, to: to)
  }

  func getAllUserQueueItems() -> [AbstractPlayable] {
    queueHandler.getAllUserQueueItems()
  }

  var nextQueueCount: Int {
    queueHandler.nextQueueCount
  }

  func getNextQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    queueHandler.getNextQueueItems(from: from, to: to)
  }

  func getAllNextQueueItems() -> [AbstractPlayable] {
    queueHandler.getAllNextQueueItems()
  }

  var totalPlayDuration: Int {
    queueHandler.totalPlayDuration
  }

  var remainingPlayDuration: Int {
    queueHandler.remainingPlayDuration
  }

  var volume: Float {
    get {
      backendAudioPlayer.volume
    }
    set {
      backendAudioPlayer.volume = newValue
    }
  }

  var isPlaying: Bool {
    backendAudioPlayer.isPlaying
  }

  var playType: PlayType? {
    backendAudioPlayer.playType
  }

  var activeStreamingBitrate: StreamingMaxBitratePreference? {
    backendAudioPlayer.activeStreamingBitrate
  }

  var activeTranscodingFormat: StreamingFormatPreference? {
    backendAudioPlayer.activeTranscodingFormat
  }

  func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable? {
    queueHandler.getPlayable(at: playerIndex)
  }

  var currentlyPlaying: AbstractPlayable? {
    musicPlayer.currentlyPlaying
  }

  var currentMusicItem: AbstractPlayable? {
    musicPlayer.currentMusicItem
  }

  var currentPodcastItem: AbstractPlayable? {
    musicPlayer.currentPodcastItem
  }

  var contextName: String {
    guard queueHandler.contextName.isEmpty else { return queueHandler.contextName }
    if queueHandler.prevQueueCount == 0, queueHandler.nextQueueCount == 0,
       queueHandler.currentlyPlaying == nil || queueHandler.isUserQueuePlaying {
      return ""
    } else {
      return "Mixed Context"
    }
  }

  var elapsedTime: Double {
    backendAudioPlayer.elapsedTime
  }

  var duration: Double {
    backendAudioPlayer.duration
  }

  var isShuffle: Bool {
    playerStatus.isShuffle
  }

  func toggleShuffle() {
    playerStatus.setShuffle(!isShuffle)
    musicPlayer.notifyShuffleUpdated()
    musicPlayer.notifyPlaylistUpdated()
  }

  var playbackRate: PlaybackRate {
    playerStatus.playbackRate
  }

  func setPlaybackRate(_ newValue: PlaybackRate) {
    playerStatus.setPlaybackRate(newValue)
    backendAudioPlayer.setPlaybackRate(newValue)
    musicPlayer.notifyPlaybackRateUpdated()
  }

  var repeatMode: RepeatMode {
    playerStatus.repeatMode
  }

  func setRepeatMode(_ newValue: RepeatMode) {
    playerStatus.setRepeatMode(newValue)
    musicPlayer.notifyRepeatUpdated()
  }

  var isOfflineMode: Bool {
    get { backendAudioPlayer.isOfflineMode }
    set { backendAudioPlayer.isOfflineMode = newValue }
  }

  var isShouldPauseAfterFinishedPlaying: Bool {
    get { musicPlayer.isShouldPauseAfterFinishedPlaying }
    set { musicPlayer.isShouldPauseAfterFinishedPlaying = newValue }
  }

  var isAutoCachePlayedItems: Bool {
    get { playerStatus.isAutoCachePlayedItems }
    set {
      playerStatus.setAutoCachePlayedItems(newValue)
      backendAudioPlayer.isAutoCachePlayedItems = newValue
    }
  }

  var isPopupBarAllowedToHide: Bool {
    playerStatus.isPopupBarAllowedToHide
  }

  var musicItemCount: Int {
    playerStatus.musicItemCount
  }

  var podcastItemCount: Int {
    playerStatus.podcastItemCount
  }

  var playerMode: PlayerMode {
    playerStatus.playerMode
  }

  func setPlayerMode(_ newValue: PlayerMode) {
    musicPlayer.stopButRemainIndex()
    playerStatus.setPlayerMode(newValue)
    musicPlayer.notifyPlaylistUpdated()
  }

  var streamingMaxBitrates: StreamingMaxBitrates { backendAudioPlayer.streamingMaxBitrates }
  public func setStreamingMaxBitrates(to: StreamingMaxBitrates) {
    backendAudioPlayer.setStreamingMaxBitrates(to: to)
  }

  var streamingTranscodings: StreamingTranscodings { backendAudioPlayer.streamingTranscodings }
  public func setStreamingTranscodings(to: StreamingTranscodings) {
    backendAudioPlayer.setStreamingTranscodings(to: to)
  }

  public func updateEqualizerEnabled(isEnabled: Bool) {
    backendAudioPlayer.updateEqualizerEnabled(isEnabled: isEnabled)
  }

  public func updateEqualizerSetting(eqSetting: EqualizerSetting) {
    backendAudioPlayer.updateEqualizerSetting(eqSetting: eqSetting)
  }

  public func updateReplayGainEnabled(isEnabled: Bool) {
    backendAudioPlayer.updateReplayGainEnabled(isEnabled: isEnabled)
  }

  func logout(account: Account) {
    if queueHandler.logout(account: account) {
      stop()
    }
  }

  func seek(toSecond: Double) {
    userStatistics.usedAction(.playerSeek)
    guard let currentlyPlaying = currentlyPlaying else { return }
    switch currentlyPlaying.derivedType {
    case .podcastEpisode, .song:
      backendAudioPlayer.seek(toSecond: toSecond)
    case .radio:
      break // do nothing
    }
  }

  func insertContextQueue(playables: [AbstractPlayable]) {
    queueHandler.insertContextQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func appendContextQueue(playables: [AbstractPlayable]) {
    queueHandler.appendContextQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func insertUserQueue(playables: [AbstractPlayable]) {
    queueHandler.insertUserQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func appendUserQueue(playables: [AbstractPlayable]) {
    queueHandler.appendUserQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func insertPodcastQueue(playables: [AbstractPlayable]) {
    queueHandler.insertPodcastQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func appendPodcastQueue(playables: [AbstractPlayable]) {
    queueHandler.appendPodcastQueue(playables: playables)
    musicPlayer.notifyPlaylistUpdated()
  }

  func removePlayable(at: PlayerIndex) {
    queueHandler.removePlayable(at: at)
  }

  func movePlayable(from: PlayerIndex, to: PlayerIndex) {
    queueHandler.movePlayable(from: from, to: to)
  }

  func clearUserQueue() {
    queueHandler.clearUserQueue()
  }

  func clearContextQueue() {
    if !queueHandler.isUserQueuePlaying {
      if queueHandler.userQueueCount == 0 {
        musicPlayer.stop()
      } else {
        play(playerIndex: PlayerIndex(queueType: .user, index: 0))
      }
    }
    queueHandler.clearContextQueue()
  }

  func clearQueues() {
    musicPlayer.stop()
    queueHandler.clearActiveQueue()
    switch playerStatus.playerMode {
    case .music:
      queueHandler.clearUserQueue()
    case .podcast:
      break
    }
    musicPlayer.notifyPlayerStopped()
  }

  func play() {
    musicPlayer.play()
  }

  func play(context: PlayContext) {
    setPlayerModeForContextPlay(context.type)
    if playerMode == .music, playerStatus.isShuffle {
      playerStatus.setShuffle(false)
      musicPlayer.notifyShuffleUpdated()
    }
    musicPlayer.play(context: context)
    musicPlayer.notifyPlaylistUpdated()
  }

  private func setPlayerModeForContextPlay(_ newValue: PlayerMode) {
    musicPlayer.pause()
    playerStatus.setPlayerMode(newValue)
  }

  func playShuffled(context: PlayContext) {
    setPlayerModeForContextPlay(context.type)
    guard !context.playables.isEmpty else { return }
    if playerStatus.isShuffle { playerStatus.setShuffle(false) }
    let shuffleContext = context.getWithShuffledIndex()
    musicPlayer.play(context: shuffleContext)
    playerStatus.setShuffle(true)
    musicPlayer.notifyShuffleUpdated()
    musicPlayer.notifyPlaylistUpdated()
  }

  func play(playerIndex: PlayerIndex) {
    musicPlayer.play(playerIndex: playerIndex)
  }

  func pause() {
    musicPlayer.pause()
  }

  func togglePlayPause() {
    musicPlayer.togglePlayPause()
  }

  func stop() {
    musicPlayer.stop()
  }

  func playPrevious() {
    musicPlayer.playPrevious()
  }

  func playPreviousOrReplay() {
    musicPlayer.playPreviousOrReplay()
  }

  func playNext() {
    musicPlayer.playNext()
  }

  func skipForward(interval: Double) {
    seek(toSecond: elapsedTime + interval)
  }

  func skipBackward(interval: Double) {
    seek(toSecond: elapsedTime - interval)
  }

  var audioAnalyzer: AudioAnalyzer {
    musicPlayer.audioAnalyzer
  }

  func addNotifier(notifier: MusicPlayable) {
    musicPlayer.addNotifier(notifier: notifier)
  }
}
