//
//  PlayerData.swift
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

import CoreData
import CoreMedia
import Foundation
import UIKit

// MARK: - PlayerStatusPersistent

protocol PlayerStatusPersistent {
  func stop()
  var isAutoCachePlayedItems: Bool { get set }
  var isPopupBarAllowedToHide: Bool { get }
  var musicItemCount: Int { get }
  var podcastItemCount: Int { get }
  var playerMode: PlayerMode { get set }
  var isShuffle: Bool { get set }
  var repeatMode: RepeatMode { get set }
  var playbackRate: PlaybackRate { get set }
  var musicPlaybackRate: PlaybackRate { get set }
  var podcastPlaybackRate: PlaybackRate { get set }
}

// MARK: - PlayerQueuesPersistent

protocol PlayerQueuesPersistent {
  var isUserQueuePlaying: Bool { get set }
  var isUserQueueVisible: Bool { get }

  var currentIndex: Int { get set }
  var currentItem: AbstractPlayable? { get }
  var currentMusicItem: AbstractPlayable? { get }
  var currentPodcastItem: AbstractPlayable? { get }
  var activeQueue: Playlist { get }
  var inactiveQueue: Playlist { get }
  var contextQueue: Playlist { get }
  var podcastQueue: Playlist { get }
  var contextName: String { get set }
  var userQueuePlaylist: Playlist { get }

  func insertActiveQueue(playables: [AbstractPlayable])
  func appendActiveQueue(playables: [AbstractPlayable])
  func insertContextQueue(playables: [AbstractPlayable])
  func appendContextQueue(playables: [AbstractPlayable])
  func insertUserQueue(playables: [AbstractPlayable])
  func appendUserQueue(playables: [AbstractPlayable])
  func insertPodcastQueue(playables: [AbstractPlayable])
  func appendPodcastQueue(playables: [AbstractPlayable])
  func clearActiveQueue()
  func clearUserQueue()
  func clearContextQueue()
  func removeAllItems()
}

// MARK: - PlayerMode

public enum PlayerMode: Int16 {
  case music = 0
  case podcast = 1

  public var nextMode: PlayerMode {
    self == .music ? .podcast : .music
  }

  public var description: String {
    switch self {
    case .music: "Music"
    case .podcast: "Podcast"
    }
  }

  public var playableName: String {
    switch self {
    case .music: "Song"
    case .podcast: "Podcast Episode"
    }
  }
}

// MARK: - PlayerData

public class PlayerData: NSObject {
  private let userQueuePlaylistInternal: Playlist
  private let library: LibraryStorage
  private let managedObject: PlayerMO
  private let contextPlaylist: Playlist
  private let shuffledContextPlaylist: Playlist
  private let podcastPlaylist: Playlist

  static let entityName: String = { "Player" }()

  init(
    library: LibraryStorage,
    managedObject: PlayerMO,
    userQueue: Playlist,
    contextQueue: Playlist,
    shuffledContextQueue: Playlist,
    podcastQueue: Playlist
  ) {
    self.library = library
    self.managedObject = managedObject
    self.userQueuePlaylistInternal = userQueue
    self.contextPlaylist = contextQueue
    self.shuffledContextPlaylist = shuffledContextQueue
    self.podcastPlaylist = podcastQueue
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let object = object as? PlayerData else { return false }
    return managedObject == object.managedObject
  }
}

// MARK: PlayerStatusPersistent

extension PlayerData: PlayerStatusPersistent {
  func stop() {
    currentIndex = 0
    switch playerMode {
    case .music:
      isUserQueuePlaying = false
      clearUserQueue()
    case .podcast:
      break
    }
  }

  var isAutoCachePlayedItems: Bool {
    get { managedObject.autoCachePlayedItemSetting == 1 }
    set {
      managedObject.autoCachePlayedItemSetting = newValue ? 1 : 0
      library.saveContext()
    }
  }

  var isPopupBarAllowedToHide: Bool {
    podcastPlaylist.songCount == 0 && contextPlaylist.songCount == 0 && userQueuePlaylistInternal
      .songCount == 0
  }

  var musicItemCount: Int {
    contextPlaylist.songCount + userQueuePlaylistInternal.songCount
  }

  var podcastItemCount: Int {
    podcastPlaylist.songCount
  }

  var playerMode: PlayerMode {
    get { PlayerMode(rawValue: managedObject.playerMode) ?? .music }
    set {
      managedObject.playerMode = newValue.rawValue
      library.saveContext()
    }
  }

  var isShuffle: Bool {
    get {
      switch playerMode {
      case .music:
        return managedObject.shuffleSetting == 1
      case .podcast:
        return false
      }
    }
    set {
      if newValue {
        shuffledContextPlaylist.shuffle()
        if let curPlayable = currentItem,
           let indexOfCurrentItemInShuffledPlaylist = shuffledContextPlaylist
           .getFirstIndex(playable: curPlayable) {
          shuffledContextPlaylist.movePlaylistItem(
            fromIndex: indexOfCurrentItemInShuffledPlaylist,
            to: 0
          )
          currentIndex = 0
        }
      } else {
        if let curPlayable = currentItem,
           let indexOfCurrentItemInNormalPlaylist = contextPlaylist
           .getFirstIndex(playable: curPlayable) {
          currentIndex = indexOfCurrentItemInNormalPlaylist
        }
      }
      managedObject.shuffleSetting = newValue ? 1 : 0
      library.saveContext()
    }
  }

  var repeatMode: RepeatMode {
    get {
      switch playerMode {
      case .music:
        return RepeatMode(rawValue: managedObject.repeatSetting) ?? .off
      case .podcast:
        return .off
      }
    }
    set {
      managedObject.repeatSetting = newValue.rawValue
      library.saveContext()
    }
  }

  var playbackRate: PlaybackRate {
    get {
      switch playerMode {
      case .music:
        return PlaybackRate.create(from: managedObject.musicPlaybackRate)
      case .podcast:
        return PlaybackRate.create(from: managedObject.podcastPlaybackRate)
      }
    }
    set {
      switch playerMode {
      case .music:
        managedObject.musicPlaybackRate = newValue.asDouble
      case .podcast:
        managedObject.podcastPlaybackRate = newValue.asDouble
      }
      library.saveContext()
    }
  }

  var musicPlaybackRate: PlaybackRate {
    get {
      PlaybackRate.create(from: managedObject.musicPlaybackRate)
    }
    set {
      managedObject.musicPlaybackRate = newValue.asDouble
      library.saveContext()
    }
  }

  var podcastPlaybackRate: PlaybackRate {
    get {
      PlaybackRate.create(from: managedObject.podcastPlaybackRate)
    }
    set {
      managedObject.podcastPlaybackRate = newValue.asDouble
      library.saveContext()
    }
  }
}

// MARK: PlayerQueuesPersistent

extension PlayerData: PlayerQueuesPersistent {
  var isUserQueuePlaying: Bool {
    get {
      switch playerMode {
      case .music:
        return isUserQueuPlayingInternal
      case .podcast:
        return false
      }
    }
    set {
      switch playerMode {
      case .music:
        isUserQueuPlayingInternal = newValue
      case .podcast:
        break
      }
    }
  }

  private var isUserQueuPlayingInternal: Bool {
    get { managedObject.isUserQueuePlaying }
    set {
      managedObject.isUserQueuePlaying = newValue
      library.saveContext()
    }
  }

  var isUserQueueVisible: Bool {
    switch playerMode {
    case .music:
      return userQueuePlaylistInternal
        .songCount > 0 && !(isUserQueuPlayingInternal && userQueuePlaylistInternal.songCount == 1)
    case .podcast:
      return false
    }
  }

  var activeMusicQueue: Playlist {
    if !isShuffle {
      return contextPlaylist
    } else {
      return shuffledContextPlaylist
    }
  }

  var activeQueue: Playlist {
    switch playerMode {
    case .music:
      return activeMusicQueue
    case .podcast:
      return podcastPlaylist
    }
  }

  var inactiveQueue: Playlist {
    switch playerMode {
    case .music:
      if !isShuffle {
        return shuffledContextPlaylist
      } else {
        return contextPlaylist
      }
    case .podcast:
      return podcastPlaylist
    }
  }

  var contextQueue: Playlist { contextPlaylist }
  var podcastQueue: Playlist { podcastPlaylist }

  var contextName: String {
    get {
      switch playerMode {
      case .music:
        return contextPlaylist.name
      case .podcast:
        return "Podcasts"
      }
    }
    set {
      contextPlaylist.name = newValue
    }
  }

  var currentIndex: Int {
    get {
      switch playerMode {
      case .music:
        return currentMusicIndex
      case .podcast:
        return currentPodcastIndex
      }
    }
    set {
      switch playerMode {
      case .music:
        currentMusicIndex = newValue
      case .podcast:
        currentPodcastIndex = newValue
      }
    }
  }

  private var currentMusicIndex: Int {
    get {
      if managedObject.musicIndex < 0, !isUserQueuPlayingInternal {
        return 0
      }
      if managedObject.musicIndex >= contextQueue.songCount || managedObject.musicIndex < -1 {
        return 0
      }
      return Int(managedObject.musicIndex)
    }
    set {
      if newValue >= -1, newValue < contextQueue.songCount {
        managedObject.musicIndex = Int32(newValue)
      } else {
        managedObject.musicIndex = isUserQueuPlayingInternal ? -1 : 0
      }
      library.saveContext()
    }
  }

  private var currentPodcastIndex: Int {
    get {
      if managedObject
        .podcastIndex < 0 ||
        (
          managedObject.podcastIndex >= podcastPlaylist.songCount && podcastPlaylist
            .songCount > 0
        ) {
        return 0
      }
      return Int(managedObject.podcastIndex)
    }
    set {
      if newValue >= 0, newValue < podcastPlaylist.songCount {
        managedObject.podcastIndex = Int32(newValue)
      } else {
        managedObject.podcastIndex = 0
      }
      library.saveContext()
    }
  }

  var currentItem: AbstractPlayable? {
    switch playerMode {
    case .music:
      return getCurrentMusicPlayable(in: activeQueue)
    case .podcast:
      return podcastPlaylist.getPlayable(at: currentPodcastIndex)
    }
  }

  var currentMusicItem: AbstractPlayable? {
    getCurrentMusicPlayable(in: activeMusicQueue)
  }

  var currentPodcastItem: AbstractPlayable? {
    podcastPlaylist.getPlayable(at: currentPodcastIndex)
  }

  private func getCurrentMusicPlayable(in queue: Playlist) -> AbstractPlayable? {
    if isUserQueuPlayingInternal, userQueuePlaylistInternal.songCount > 0 {
      return userQueuePlaylistInternal.getPlayable(at: 0)
    }
    guard queue.songCount > 0 else { return nil }
    guard currentMusicIndex >= 0, currentMusicIndex < queue.songCount else {
      return queue.getPlayable(at: 0)
    }
    return queue.getPlayable(at: currentMusicIndex)
  }

  var userQueuePlaylist: Playlist { userQueuePlaylistInternal }

  func insertActiveQueue(playables: [AbstractPlayable]) {
    switch playerMode {
    case .music:
      insertContextQueue(playables: playables)
    case .podcast:
      insertPodcastQueue(playables: playables)
    }
  }

  func appendActiveQueue(playables: [AbstractPlayable]) {
    switch playerMode {
    case .music:
      appendContextQueue(playables: playables)
    case .podcast:
      appendPodcastQueue(playables: playables)
    }
  }

  func insertContextQueue(playables: [AbstractPlayable]) {
    var targetIndex = currentMusicIndex + 1
    if contextPlaylist.songCount == 0 {
      if isUserQueuPlayingInternal {
        currentMusicIndex = -1
      }
      targetIndex = 0
    }
    contextPlaylist.insert(playables: playables, index: targetIndex)
    shuffledContextPlaylist.insert(playables: playables, index: targetIndex)
  }

  func appendContextQueue(playables: [AbstractPlayable]) {
    contextPlaylist.append(playables: playables)
    shuffledContextPlaylist.append(playables: playables)
  }

  func insertUserQueue(playables: [AbstractPlayable]) {
    let targetIndex = isUserQueuPlayingInternal && userQueuePlaylistInternal.songCount > 0 ? 1 : 0
    userQueuePlaylistInternal.insert(playables: playables, index: targetIndex)
  }

  func appendUserQueue(playables: [AbstractPlayable]) {
    userQueuePlaylistInternal.append(playables: playables)
  }

  func insertPodcastQueue(playables: [AbstractPlayable]) {
    var targetIndex = currentPodcastIndex + 1
    if podcastPlaylist.songCount == 0 {
      targetIndex = 0
    }
    podcastPlaylist.insert(playables: playables, index: targetIndex)
  }

  func appendPodcastQueue(playables: [AbstractPlayable]) {
    podcastPlaylist.append(playables: playables)
  }

  func clearActiveQueue() {
    switch playerMode {
    case .music:
      clearContextQueue()
    case .podcast:
      podcastPlaylist.removeAllItems()
      currentIndex = 0
    }
  }

  func clearContextQueue() {
    contextName = ""
    contextPlaylist.removeAllItems()
    shuffledContextPlaylist.removeAllItems()
    if userQueuePlaylistInternal.songCount > 0 {
      isUserQueuPlayingInternal = true
      currentMusicIndex = -1
    } else {
      currentMusicIndex = 0
    }
  }

  func clearUserQueue() {
    userQueuePlaylistInternal.removeAllItems()
  }

  func removeAllItems() {
    currentIndex = 0
    isUserQueuPlayingInternal = false
    contextPlaylist.removeAllItems()
    shuffledContextPlaylist.removeAllItems()
    userQueuePlaylistInternal.removeAllItems()
    podcastPlaylist.removeAllItems()
  }
}
