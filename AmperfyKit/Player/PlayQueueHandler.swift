//
//  PlayQueueHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 18.11.21.
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

public class PlayQueueHandler {
  private var playerQueues: PlayerQueuesPersistent

  init(playerData: PlayerQueuesPersistent) {
    self.playerQueues = playerData
  }

  var currentlyPlaying: AbstractPlayable? {
    playerQueues.currentItem
  }

  var currentMusicItem: AbstractPlayable? {
    playerQueues.currentMusicItem
  }

  var currentPodcastItem: AbstractPlayable? {
    playerQueues.currentPodcastItem
  }

  var totalPlayDuration: Int {
    activeQueue.duration + userQueuePlaylist.duration
  }

  var remainingPlayDuration: Int {
    getNextQueueItems(from: 0, to: nil).reduce(0) { $0 + $1.duration } + userQueuePlaylist.duration
  }

  var prevQueueCount: Int {
    var count = 0
    if isUserQueuePlaying, currentIndex == -1 {
      count = 0 // prev is empty
    } else if isUserQueuePlaying, currentIndex == 0, activeQueue.songCount > 0 {
      count = 1
    } else if currentIndex > 0 {
      if isUserQueuePlaying {
        count = currentIndex + 1
      } else {
        count = currentIndex
      }
    }
    return count
  }

  func getPrevQueueItem(at: Int) -> AbstractPlayable? {
    let count = prevQueueCount
    guard count > 0, at < count else { return nil }
    return activeQueue.getPlayable(at: at)
  }

  func getPrevQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    let count = prevQueueCount
    guard count > 0 else { return [AbstractPlayable]() }
    let end = to ?? count - 1
    guard from >= 0, end >= 0, from <= end, end < count else { return [AbstractPlayable]() }

    return activeQueue.getPlayables(from: from, to: end)
  }

  func getAllPrevQueueItems() -> [AbstractPlayable] {
    let count = prevQueueCount
    guard count > 0 else { return [AbstractPlayable]() }
    return activeQueue.getPlayables(from: 0, to: count - 1)
  }

  var userQueueCount: Int {
    var userQueue = 0
    if isUserQueueVisible {
      if isUserQueuePlaying {
        userQueue = userQueuePlaylist.songCount - 1
      } else {
        userQueue = userQueuePlaylist.songCount
      }
    }
    return userQueue
  }

  func getUserQueueItem(at: Int) -> AbstractPlayable? {
    if isUserQueueVisible {
      if isUserQueuePlaying {
        return userQueuePlaylist.getPlayable(at: at + 1)
      } else {
        return userQueuePlaylist.getPlayable(at: at)
      }
    }
    return nil
  }

  func getUserQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    let count = userQueueCount
    guard count > 0 else { return [AbstractPlayable]() }
    let end = to ?? count - 1
    guard from >= 0, end >= 0, from <= end, end < count else { return [AbstractPlayable]() }

    var userQueue = [AbstractPlayable]()
    if isUserQueueVisible {
      if isUserQueuePlaying {
        userQueue = userQueuePlaylist.getPlayables(from: from + 1, to: end + 1)
      } else {
        userQueue = userQueuePlaylist.getPlayables(from: from, to: end)
      }
    }
    return userQueue
  }

  func getAllUserQueueItems() -> [AbstractPlayable] {
    var userQueue = [AbstractPlayable]()
    if isUserQueueVisible {
      if isUserQueuePlaying {
        userQueue = userQueuePlaylist.getPlayables(from: 1)
      } else {
        userQueue = userQueuePlaylist.getPlayables(from: 0)
      }
    }
    return userQueue
  }

  var nextQueueCount: Int {
    if activeQueue.songCount > 0, currentIndex < activeQueue.songCount - 1 {
      return activeQueue.songCount - currentIndex - 1
    } else {
      return 0
    }
  }

  func getNextQueueItem(at: Int) -> AbstractPlayable? {
    let count = nextQueueCount
    if count > 0, at < count {
      return activeQueue.getPlayable(at: at + currentIndex + 1)
    } else {
      return nil
    }
  }

  func getNextQueueItems(from: Int, to: Int?) -> [AbstractPlayable] {
    let count = nextQueueCount
    guard count > 0 else { return [AbstractPlayable]() }
    let end = to ?? count - 1
    guard from >= 0, end >= 0, from <= end, end < count else { return [AbstractPlayable]() }

    if count > 0 {
      let offset = currentIndex + 1
      return activeQueue.getPlayables(from: from + offset, to: end + offset)
    } else {
      return [AbstractPlayable]()
    }
  }

  func getAllNextQueueItems() -> [AbstractPlayable] {
    let count = nextQueueCount
    if count > 0 {
      return activeQueue.getPlayables(from: currentIndex + 1)
    } else {
      return [AbstractPlayable]()
    }
  }

  var contextName: String { playerQueues.contextName }

  func setContextName(_ newValue: String) {
    playerQueues.setContextName(newValue)
  }

  var isUserQueuePlaying: Bool {
    playerQueues.isUserQueuePlaying
  }

  func insertActiveQueue(playables: [AbstractPlayable]) {
    playerQueues.insertActiveQueue(playables: playables)
  }

  func appendActiveQueue(playables: [AbstractPlayable]) {
    playerQueues.appendActiveQueue(playables: playables)
  }

  func insertContextQueue(playables: [AbstractPlayable]) {
    playerQueues.setContextName("")
    playerQueues.insertContextQueue(playables: playables)
  }

  func appendContextQueue(playables: [AbstractPlayable]) {
    playerQueues.setContextName("")
    playerQueues.appendContextQueue(playables: playables)
  }

  func insertUserQueue(playables: [AbstractPlayable]) {
    playerQueues.insertUserQueue(playables: playables)
    if playerQueues.contextQueue.songCount == 0 {
      playerQueues.setUserQueuePlaying(true)
    }
  }

  func appendUserQueue(playables: [AbstractPlayable]) {
    playerQueues.appendUserQueue(playables: playables)
    if playerQueues.contextQueue.songCount == 0 {
      playerQueues.setUserQueuePlaying(true)
    }
  }

  func insertPodcastQueue(playables: [AbstractPlayable]) {
    playerQueues.insertPodcastQueue(playables: playables)
  }

  func appendPodcastQueue(playables: [AbstractPlayable]) {
    playerQueues.appendPodcastQueue(playables: playables)
  }

  func clearActiveQueue() {
    playerQueues.clearActiveQueue()
  }

  func clearContextQueue() {
    playerQueues.setContextName("")
    playerQueues.clearContextQueue()
  }

  func clearUserQueue() {
    if isUserQueuePlaying, let currentUserQueueItem = currentlyPlaying {
      playerQueues.clearUserQueue()
      insertUserQueue(playables: [currentUserQueueItem])
    } else {
      playerQueues.clearUserQueue()
    }
  }

  func removeAllItems() {
    playerQueues.setContextName("")
    playerQueues.removeAllItems()
  }

  func markAndGetPlayableAsPlaying(at playerIndex: PlayerIndex) -> AbstractPlayable? {
    var playable: AbstractPlayable?
    if playerIndex.queueType == .user, playerIndex.index >= 0, playerIndex.index < userQueueCount {
      playable = getUserQueueItem(at: playerIndex.index)
      if isUserQueuePlaying {
        removeItemFromUserQueue(at: 0)
      }
      if playerIndex.index > 0 {
        for _ in 1 ... playerIndex.index {
          removeItemFromUserQueue(at: 0)
        }
      }
      playerQueues.setUserQueuePlaying(true)
    } else if playerIndex.queueType == .prev, playerIndex.index >= 0,
              playerIndex.index < prevQueueCount {
      if isUserQueuePlaying {
        removeItemFromUserQueue(at: 0)
      }
      playable = getPrevQueueItem(at: playerIndex.index)
      setCurrentIndex(playerIndex.index)
      playerQueues.setUserQueuePlaying(false)
    } else if playerIndex.queueType == .next, playerIndex.index >= 0,
              playerIndex.index < nextQueueCount {
      if isUserQueuePlaying {
        removeItemFromUserQueue(at: 0)
      }
      playable = getNextQueueItem(at: playerIndex.index)
      if isUserQueuePlaying {
        setCurrentIndex(prevQueueCount + playerIndex.index)
      } else {
        setCurrentIndex(prevQueueCount + 1 + playerIndex.index)
      }
      playerQueues.setUserQueuePlaying(false)
    }
    return playable
  }

  func removePlayable(at: PlayerIndex) {
    switch at.queueType {
    case .user:
      if isUserQueuePlaying {
        removeItemFromUserQueue(at: at.index + 1)
      } else {
        removeItemFromUserQueue(at: at.index)
      }
    case .prev:
      removeItemFromActiveQueue(at: at.index)
    case .next:
      var playlistIndex = prevQueueCount + at.index
      if !isUserQueuePlaying {
        playlistIndex += 1
      }
      removeItemFromActiveQueue(at: playlistIndex)
    }
  }

  func movePlayable(from: PlayerIndex, to: PlayerIndex) {
    let userQueueOffsetIsUserQueuePlaying = isUserQueuePlaying ? 1 : 0
    let nextQueueOffsetIsUserQueuePlaying = isUserQueuePlaying ? 0 : 1
    let offsetToNext = prevQueueCount + nextQueueOffsetIsUserQueuePlaying

    guard from.index >= 0, to.index >= 0 else { return }

    if from.queueType == .prev { guard from.index < prevQueueCount else { return } }
    if from.queueType == .user { guard from.index < userQueueCount else { return } }
    if from.queueType == .next { guard from.index < nextQueueCount else { return } }

    if to.queueType == .prev { guard to.index <= prevQueueCount else { return } }
    if to.queueType == .user { guard to.index <= userQueueCount else { return } }
    if to.queueType == .next { guard to.index <= nextQueueCount else { return } }

    // Prev <=> Prev
    if from.queueType == .prev, to.queueType == .prev {
      moveContextItem(fromIndex: from.index, to: to.index)
      // Next <=> Next
    } else if from.queueType == .next, to.queueType == .next {
      moveContextItem(fromIndex: offsetToNext + from.index, to: offsetToNext + to.index)
      // User <=> User
    } else if from.queueType == .user, to.queueType == .user {
      moveUserQueueItem(
        fromIndex: from.index + userQueueOffsetIsUserQueuePlaying,
        to: to.index + userQueueOffsetIsUserQueuePlaying
      )

      // Prev ==> Next
    } else if from.queueType == .prev, to.queueType == .next {
      if !isUserQueuePlaying {
        moveContextItem(fromIndex: from.index, to: offsetToNext + to.index - 1)
      } else if from.index == currentIndex, to.index == 0 {
        setCurrentIndex(currentIndex - 1)
      } else {
        moveContextItem(fromIndex: from.index, to: offsetToNext + to.index - 1)
        setCurrentIndex(currentIndex - 1)
      }
      // Next ==> Prev
    } else if from.queueType == .next, to.queueType == .prev {
      if !isUserQueuePlaying {
        moveContextItem(fromIndex: offsetToNext + from.index, to: to.index)
      } else if from.index == 0, to.index == currentIndex + 1 {
        setCurrentIndex(currentIndex + 1)
      } else {
        moveContextItem(fromIndex: offsetToNext + from.index, to: to.index)
        setCurrentIndex(currentIndex + 1)
      }

      // User ==> Next
    } else if from.queueType == .user, to.queueType == .next {
      playerQueues.appendContextQueue(playables: [getUserQueueItem(at: from.index)!])
      let fromIndex = activeQueue.songCount - 1
      moveContextItem(fromIndex: fromIndex, to: offsetToNext + to.index)
      removeItemFromUserQueue(at: from.index + userQueueOffsetIsUserQueuePlaying)
      // User ==> Prev
    } else if from.queueType == .user, to.queueType == .prev {
      playerQueues.appendContextQueue(playables: [getUserQueueItem(at: from.index)!])
      let fromIndex = activeQueue.songCount - 1
      moveContextItem(fromIndex: fromIndex, to: to.index)
      if isUserQueuePlaying {
        setCurrentIndex(currentIndex + 1)
      }
      removeItemFromUserQueue(at: from.index + userQueueOffsetIsUserQueuePlaying)

      // Prev ==> User
    } else if from.queueType == .prev, to.queueType == .user {
      playerQueues.appendUserQueue(playables: [getPrevQueueItem(at: from.index)!])
      moveUserQueueItem(
        fromIndex: userQueuePlaylist.songCount - 1,
        to: to.index + userQueueOffsetIsUserQueuePlaying
      )
      removeItemFromActiveQueue(at: from.index)
      // Next ==> User
    } else if from.queueType == .next, to.queueType == .user {
      playerQueues.appendUserQueue(playables: [getNextQueueItem(at: from.index)!])
      moveUserQueueItem(
        fromIndex: userQueuePlaylist.songCount - 1,
        to: to.index + userQueueOffsetIsUserQueuePlaying
      )
      removeItemFromActiveQueue(at: offsetToNext + from.index)
    }
  }

  func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable? {
    switch playerIndex.queueType {
    case .prev:
      return getPrevQueueItem(at: playerIndex.index)
    case .user:
      return getUserQueueItem(at: playerIndex.index)
    case .next:
      return getNextQueueItem(at: playerIndex.index)
    }
  }

  // returns true if the player has been reseted
  func logout(account: Account) -> Bool {
    // if one playlist contain an element from the logout account -> reset complete player
    if playerQueues.contextQueue.playables.contains(where: { $0.account == account }) ||
      playerQueues.userQueuePlaylist.playables.contains(where: { $0.account == account }) ||
      playerQueues.podcastQueue.playables.contains(where: { $0.account == account }) {
      removeAllItems()
      return true
    }
    return false
  }

  private var currentIndex: Int { playerQueues.currentIndex }

  func setCurrentIndex(_ newValue: Int) {
    playerQueues.setCurrentIndex(newValue)
  }

  private var activeQueue: Playlist {
    playerQueues.activeQueue
  }

  private var userQueuePlaylist: Playlist {
    playerQueues.userQueuePlaylist
  }

  private var isUserQueueVisible: Bool {
    playerQueues.isUserQueueVisible
  }

  private func removeItemFromUserQueue(at index: Int) {
    guard index < userQueuePlaylist.songCount else { return }
    userQueuePlaylist.remove(at: index)
  }

  private func removeItemFromActiveQueue(at index: Int) {
    guard index < activeQueue.songCount else { return }
    let playableToRemove = activeQueue.getPlayable(at: index)!
    if index < currentIndex {
      setCurrentIndex(currentIndex - 1)
    } else if isUserQueuePlaying, index == currentIndex {
      setCurrentIndex(currentIndex - 1)
    }
    activeQueue.remove(at: index)
    playerQueues.inactiveQueue.remove(firstOccurrenceOfPlayable: playableToRemove)
  }

  private func moveContextItem(fromIndex: Int, to: Int) {
    guard fromIndex < activeQueue.songCount, to < activeQueue.songCount,
          fromIndex != to else { return }
    activeQueue.movePlaylistItem(fromIndex: fromIndex, to: to)
    guard !isUserQueuePlaying else { return }
    if currentIndex == fromIndex {
      setCurrentIndex(to)
    } else if fromIndex < currentIndex, currentIndex <= to {
      setCurrentIndex(currentIndex - 1)
    } else if to <= currentIndex, currentIndex < fromIndex {
      setCurrentIndex(currentIndex + 1)
    }
  }

  private func moveUserQueueItem(fromIndex: Int, to: Int) {
    guard fromIndex < userQueuePlaylist.songCount, to < userQueuePlaylist.songCount,
          fromIndex != to else { return }
    userQueuePlaylist.movePlaylistItem(fromIndex: fromIndex, to: to)
  }
}
