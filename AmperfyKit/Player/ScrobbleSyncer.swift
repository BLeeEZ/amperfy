//
//  ScrobbleSyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.03.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import Foundation
import os.log

// MARK: - ScrobbleSyncer

@MainActor
public class ScrobbleSyncer {
  private static let maximumWaitDurationInSec: TimeInterval =
    240 // scrobble at 4 min or 50% of duration

  private let log = OSLog(subsystem: "Amperfy", category: "ScrobbleSyncer")
  private let player: PlayerFacade
  private let networkMonitor: NetworkMonitorFacade
  private let account: Account
  private let accountObjectId: NSManagedObjectID
  private let storage: PersistentStorage
  private let librarySyncer: LibrarySyncer
  private let eventLogger: EventLogger
  private var isRunning = false
  private var isActive = false
  private var scrobbleTimer: Timer?

  // Track how long the song has actually been played
  private var accumulatedPlayTime: TimeInterval = 0
  private var playStartTimestamp: Date?
  private var currentSongThreshold: TimeInterval = 0

  private var songToBeScrobbled: Song?
  private var songHasBeenListendEnough = false

  init(
    player: PlayerFacade,
    networkMonitor: NetworkMonitorFacade,
    account: Account,
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    eventLogger: EventLogger
  ) {
    self.player = player
    self.networkMonitor = networkMonitor
    self.account = account
    self.accountObjectId = account.managedObject.objectID
    self.storage = storage
    self.librarySyncer = librarySyncer
    self.eventLogger = eventLogger
  }

  public func start() {
    guard storage.main.library.getUploadableScrobbleEntryCount(for: account) > 0 else { return }
    isRunning = true
    if !isActive {
      isActive = true
      uploadInBackground()
    }
  }

  public func stop() {
    isRunning = false
  }

  private func scrobble(playedSong: Song, songPosition: NowPlayingSongPosition) async {
    func nowPlayingToServerAsync(
      playedSong: Song,
      songPosition: NowPlayingSongPosition,
      finallyCB: ((_: Song, _: Bool) -> ())? = nil
    ) {
      var success = false
      Task { @MainActor in
        do {
          try await self.librarySyncer.syncNowPlaying(song: playedSong, songPosition: songPosition)
          success = true
        } catch {
          os_log(
            "Now Playing Sync Failed: %s",
            log: self.log,
            type: .info,
            playedSong.displayString
          )
          self.eventLogger.report(topic: "Scrobble Sync", error: error, displayPopup: false)
        }
        finallyCB?(playedSong, success)
      }
    }

    switch songPosition {
    case .start:
      if storage.settings.user.isOnlineMode, networkMonitor.isConnectedToNetwork {
        nowPlayingToServerAsync(playedSong: playedSong, songPosition: .start)
      }
    case .end:
      if storage.settings.user.isOnlineMode, networkMonitor.isConnectedToNetwork {
        nowPlayingToServerAsync(playedSong: playedSong, songPosition: .end) { song, success in
          self.cacheScrobbleRequest(playedSong: song, isUploaded: success)
          guard success else { return }
          self.start() // send cached request to server
        }
      } else {
        cacheScrobbleRequest(playedSong: playedSong, isUploaded: false)
      }
    }
  }

  private func uploadInBackground() {
    Task { @MainActor in
      os_log("start", log: self.log, type: .info)

      while self.isRunning, self.storage.settings.user.isOnlineMode,
            self.networkMonitor.isConnectedToNetwork {
        do {
          let scobbleEntry = try await self.getNextScrobbleEntry()
          guard let entry = scobbleEntry else {
            self.isRunning = false
            continue
          }
          guard let song = entry.playable?.asSong, let date = entry.date else {
            entry.isUploaded = true
            self.storage.main.saveContext()
            continue
          }
          try await self.librarySyncer.scrobble(song: song, date: date)
          entry.isUploaded = true
          self.storage.main.saveContext()
        } catch {
          self.isRunning = false
          self.eventLogger.report(topic: "Scrobble Sync", error: error, displayPopup: false)
        }
      }

      os_log("stopped", log: self.log, type: .info)
      self.isActive = false
    }
  }

  private func getNextScrobbleEntry() async throws -> ScrobbleEntry? {
    let scobbleObjectId: NSManagedObjectID? = try? await storage.async
      .performAndGet { asyncCompanion in
        let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
        guard let scobbleEntry = asyncCompanion.library
          .getFirstUploadableScrobbleEntry(for: accountAsync) else {
          return nil
        }
        return scobbleEntry.managedObject.objectID
      }
    guard let scobbleObjectId else { return nil }
    return ScrobbleEntry(
      managedObject: try! storage.main.context
        .existingObject(with: scobbleObjectId) as! ScrobbleEntryMO
    )
  }

  private func cacheScrobbleRequest(playedSong: Song, isUploaded: Bool) {
    if !isUploaded {
      os_log("Scrobble cache: %s", log: self.log, type: .info, playedSong.displayString)
    }
    let scrobbleEntry = storage.main.library.createScrobbleEntry(account: account)
    scrobbleEntry.date = Date()
    scrobbleEntry.playable = playedSong
    scrobbleEntry.isUploaded = isUploaded
    storage.main.saveContext()
  }

  private func startSongPlayed() async {
    await syncSongStopped(clearCurPlaying: true)

    guard let curPlaying = player.currentlyPlaying,
          let curPlayingSong = curPlaying.asSong,
          curPlayingSong.account == account
    else { return }

    songToBeScrobbled = curPlayingSong

    // Reset tracking variables
    accumulatedPlayTime = 0
    playStartTimestamp = Date()

    // Calculate threshold time (half of duration or maximum)
    let waitDuration = TimeInterval(curPlayingSong.duration) / 2
    if waitDuration > Self.maximumWaitDurationInSec {
      currentSongThreshold = Self.maximumWaitDurationInSec
    } else {
      currentSongThreshold = waitDuration
    }

    startScrobbleTimer(forSong: curPlayingSong, withDuration: currentSongThreshold)
  }

  private func startScrobbleTimer(forSong song: Song, withDuration duration: TimeInterval) {
    let curPlayingId = song.managedObject.objectID

    scrobbleTimer?.invalidate()
    scrobbleTimer = Timer.scheduledTimer(
      withTimeInterval: duration,
      repeats: false
    ) { _ in
      Task { @MainActor in
        let curPlayingClosureMO = self.storage.main.context.object(with: curPlayingId) as! SongMO
        let curPlayingClosure = Song(managedObject: curPlayingClosureMO)
        guard curPlayingClosure == self.player.currentlyPlaying,
              self.player.playType == .cache || self.storage.settings
              .accounts.getSetting(self.account.info).read.isScrobbleStreamedItems
        else { return }
        self.songHasBeenListendEnough = true
      }
    }
  }

  private func syncSongStopped(clearCurPlaying: Bool) async {
    func clearingCurPlaying() {
      songHasBeenListendEnough = false
      scrobbleTimer?.invalidate()
      scrobbleTimer = nil
      songToBeScrobbled = nil
      accumulatedPlayTime = 0
      playStartTimestamp = nil
      currentSongThreshold = 0
    }

    if let oldSong = songToBeScrobbled,
       songHasBeenListendEnough {
      await scrobble(playedSong: oldSong, songPosition: .end)
      clearingCurPlaying()
    } else if clearCurPlaying {
      clearingCurPlaying()
    }
  }
}

// MARK: MusicPlayable

extension ScrobbleSyncer: MusicPlayable {
  public func didStartPlayingFromBeginning() {
    Task { await startSongPlayed() }
  }

  public func didStartPlaying() {
    guard let curPlaying = player.currentlyPlaying,
          let curPlayingSong = curPlaying.asSong,
          curPlayingSong.account == account
    else { return }

    // Check if it's still the same song after a pause
    if let songToBeScrobbled = songToBeScrobbled, songToBeScrobbled == curPlayingSong {
      // Record when we started playing again
      playStartTimestamp = Date()

      // Only restart the timer if we haven't already hit the threshold
      if !songHasBeenListendEnough {
        // Calculate remaining time needed
        let remainingTime = currentSongThreshold - accumulatedPlayTime
        if remainingTime > 0 {
          // Start a new timer with just the remaining time needed
          startScrobbleTimer(forSong: curPlayingSong, withDuration: remainingTime)
        } else {
          // Threshold met, mark it immediately
          songHasBeenListendEnough = true
        }
      }
    }

    Task { await scrobble(playedSong: curPlayingSong, songPosition: .start) }
  }

  public func didPause() {
    // Update the accumulated play time when paused
    if let startTime = playStartTimestamp {
      let playedTime = Date().timeIntervalSince(startTime)
      accumulatedPlayTime += playedTime
      playStartTimestamp = nil
    }

    // Cancel the current timer
    scrobbleTimer?.invalidate()
    scrobbleTimer = nil

    Task { await syncSongStopped(clearCurPlaying: false) }
  }

  public func didStopPlaying() {
    Task { await syncSongStopped(clearCurPlaying: true) }
  }

  public func didElapsedTimeChange() {}
  public func didPlaylistChange() {}
  public func didArtworkChange() {}
  public func didShuffleChange() {}
  public func didRepeatChange() {}
  public func didPlaybackRateChange() {}
}
