//
//  PlayMediaIntentHandler.swift
//  Amperfy
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
