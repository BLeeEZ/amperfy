//
//  AmperfyIntentHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.06.22.
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

import AmperfyKit
import Foundation
import Intents
import OSLog

// MARK: - SearchAndPlayIntentHandler

public class SearchAndPlayIntentHandler: NSObject, SearchAndPlayIntentHandling {
  @MainActor
  let intentManager: IntentManager

  public init(intentManager: IntentManager) {
    self.intentManager = intentManager
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveSearchTerm(for intent: SearchAndPlayIntent) async -> INStringResolutionResult {
    INStringResolutionResult.success(with: intent.searchTerm ?? "")
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveShuffleOption(for intent: SearchAndPlayIntent) async
    -> ShuffleTypeResolutionResult {
    ShuffleTypeResolutionResult.success(with: intent.shuffleOption)
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveRepeatOption(for intent: SearchAndPlayIntent) async
    -> RepeatTypeResolutionResult {
    RepeatTypeResolutionResult.success(with: intent.repeatOption)
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveSearchCategory(for intent: SearchAndPlayIntent) async
    -> PlayableContainerTypeResolutionResult {
    PlayableContainerTypeResolutionResult.success(with: intent.searchCategory)
  }

  public func handle(intent: SearchAndPlayIntent) async -> SearchAndPlayIntentResponse {
    let userActivity = NSUserActivity(activityType: NSUserActivity.searchAndPlayActivityType)
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.searchTerm.rawValue: intent
          .searchTerm ?? "",
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.searchCategory.rawValue: intent
          .searchCategory.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.shuffleOption.rawValue: intent
          .shuffleOption.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.repeatOption.rawValue: intent
          .repeatOption.rawValue,
      ])

    let success = await intentManager.handleIncomingIntent(userActivity: userActivity)
    return SearchAndPlayIntentResponse(code: success ? .success : .failure, userActivity: nil)
  }
}

// MARK: - PlayIDIntentHandler

public class PlayIDIntentHandler: NSObject, PlayIDIntentHandling {
  @MainActor
  let intentManager: IntentManager

  public init(intentManager: IntentManager) {
    self.intentManager = intentManager
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveId(for intent: PlayIDIntent) async -> INStringResolutionResult {
    INStringResolutionResult.success(with: intent.id ?? "")
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveShuffleOption(for intent: PlayIDIntent) async -> ShuffleTypeResolutionResult {
    ShuffleTypeResolutionResult.success(with: intent.shuffleOption)
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveRepeatOption(for intent: PlayIDIntent) async -> RepeatTypeResolutionResult {
    RepeatTypeResolutionResult.success(with: intent.repeatOption)
  }

  @available(iOSApplicationExtension 13.0, *)
  public func resolveLibraryElementType(for intent: PlayIDIntent) async
    -> PlayableContainerTypeResolutionResult {
    PlayableContainerTypeResolutionResult.success(with: intent.libraryElementType)
  }

  public func handle(intent: PlayIDIntent) async -> PlayIDIntentResponse {
    let userActivity = NSUserActivity(activityType: NSUserActivity.playIdActivityType)
    userActivity
      .addUserInfoEntries(from: [NSUserActivity.ActivityKeys.id.rawValue: intent.id ?? ""])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.libraryElementType.rawValue: intent
          .libraryElementType.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.shuffleOption.rawValue: intent
          .shuffleOption.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.repeatOption.rawValue: intent
          .repeatOption.rawValue,
      ])

    let success = await intentManager.handleIncomingIntent(userActivity: userActivity)
    return PlayIDIntentResponse(code: success ? .success : .failure, userActivity: nil)
  }
}

// MARK: - PlayRandomSongsIntentHandler

public class PlayRandomSongsIntentHandler: NSObject, PlayRandomSongsIntentHandling {
  @MainActor
  let intentManager: IntentManager

  public init(intentManager: IntentManager) {
    self.intentManager = intentManager
  }

  public func handle(intent: PlayRandomSongsIntent) async -> PlayRandomSongsIntentResponse {
    let userActivity = NSUserActivity(activityType: NSUserActivity.playRandomSongsActivityType)
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.libraryElementType
          .rawValue: PlayableContainerType.song.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [NSUserActivity.ActivityKeys.shuffleOption.rawValue: true])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.onlyCached.rawValue: intent
          .filterOption.rawValue,
      ])

    let _ = await intentManager.handleIncomingIntent(userActivity: userActivity)
    return PlayRandomSongsIntentResponse()
  }

  public func resolveFilterOption(for intent: PlayRandomSongsIntent) async
    -> PlayRandomSongsFilterTypeResolutionResult {
    .success(with: intent.filterOption)
  }
}

// MARK: - PlayMediaIntentHandler

@MainActor
public class PlayMediaIntentHandler: NSObject,
  @preconcurrency INPlayMediaIntentHandling {
  let intentManager: IntentManager

  public init(intentManager: IntentManager) {
    self.intentManager = intentManager
  }

  @available(iOS 13.0, *)
  public func resolveMediaItems(for intent: INPlayMediaIntent) async
    -> [INPlayMediaMediaItemResolutionResult] {
    let mediaItemsToPlay = intentManager.handleIncomingPlayMediaIntent(playMediaIntent: intent)
    if let mediaItem = mediaItemsToPlay?.item {
      return INPlayMediaMediaItemResolutionResult.successes(with: [mediaItem])
    } else {
      return INPlayMediaMediaItemResolutionResult.successes(with: [])
    }
  }

  @available(iOS 13.0, *)
  public func resolvePlayShuffled(for intent: INPlayMediaIntent) async
    -> INBooleanResolutionResult {
    INBooleanResolutionResult.success(with: intent.playShuffled ?? false)
  }

  @available(iOS 13.0, *)
  public func resolvePlaybackRepeatMode(for intent: INPlayMediaIntent) async
    -> INPlaybackRepeatModeResolutionResult {
    INPlaybackRepeatModeResolutionResult.success(with: intent.playbackRepeatMode)
  }

  @available(iOS 13.0, *)
  public func resolveResumePlayback(for intent: INPlayMediaIntent) async
    -> INBooleanResolutionResult {
    INBooleanResolutionResult.success(with: intent.resumePlayback ?? true)
  }

  @available(iOS 13.0, *)
  public func resolvePlaybackQueueLocation(for intent: INPlayMediaIntent) async
    -> INPlaybackQueueLocationResolutionResult {
    INPlaybackQueueLocationResolutionResult.success(with: intent.playbackQueueLocation)
  }

  @available(iOS 13.0, *)
  public func resolvePlaybackSpeed(for intent: INPlayMediaIntent) async
    -> INPlayMediaPlaybackSpeedResolutionResult {
    INPlayMediaPlaybackSpeedResolutionResult.success(with: intent.playbackSpeed ?? 1.0)
  }

  public func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
    let shuffleOption = intent.playShuffled ?? false
    let repeatOption = RepeatMode.fromINPlaybackRepeatMode(mode: intent.playbackRepeatMode)

    let success = await intentManager.playLastResult(
      shuffleOption: shuffleOption,
      repeatOption: repeatOption
    )
    return INPlayMediaIntentResponse(code: success ? .success : .failure, userActivity: nil)
  }
}
