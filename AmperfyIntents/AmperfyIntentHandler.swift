//
//  AmperfyIntentHandler.swift
//  AmperfyIntents
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

import Foundation
import Intents
import AmperfyKit

public class SearchAndPlayIntentHandler: NSObject, SearchAndPlayIntentHandling {
    @available(iOSApplicationExtension 13.0, *)
    public func resolveSearchTerm(for intent: SearchAndPlayIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(INStringResolutionResult.success(with: intent.searchTerm ?? ""))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveShuffleOption(for intent: SearchAndPlayIntent, with completion: @escaping (ShuffleTypeResolutionResult) -> Void) {
        completion(ShuffleTypeResolutionResult.success(with: intent.shuffleOption))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveRepeatOption(for intent: SearchAndPlayIntent, with completion: @escaping (RepeatTypeResolutionResult) -> Void) {
        completion(RepeatTypeResolutionResult.success(with: intent.repeatOption))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveSearchCategory(for intent: SearchAndPlayIntent, with completion: @escaping (PlayableContainerTypeResolutionResult) -> Void) {
        completion(PlayableContainerTypeResolutionResult.success(with: intent.searchCategory))
    }
    
    public func handle(intent: SearchAndPlayIntent, completion: @escaping (SearchAndPlayIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSUserActivity.searchAndPlayActivityType)
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.searchTerm.rawValue: intent.searchTerm ?? ""])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.searchCategory.rawValue: intent.searchCategory.rawValue])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.shuffleOption.rawValue: intent.shuffleOption.rawValue])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.repeatOption.rawValue: intent.repeatOption.rawValue])
        let response = SearchAndPlayIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}

public class PlayIDIntentHandler: NSObject, PlayIDIntentHandling {
    @available(iOSApplicationExtension 13.0, *)
    public func resolveId(for intent: PlayIDIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(INStringResolutionResult.success(with: intent.id ?? ""))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveShuffleOption(for intent: PlayIDIntent, with completion: @escaping (ShuffleTypeResolutionResult) -> Void) {
        completion(ShuffleTypeResolutionResult.success(with: intent.shuffleOption))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveRepeatOption(for intent: PlayIDIntent, with completion: @escaping (RepeatTypeResolutionResult) -> Void) {
        completion(RepeatTypeResolutionResult.success(with: intent.repeatOption))
    }
    
    @available(iOSApplicationExtension 13.0, *)
    public func resolveLibraryElementType(for intent: PlayIDIntent, with completion: @escaping (PlayableContainerTypeResolutionResult) -> Void) {
        completion(PlayableContainerTypeResolutionResult.success(with: intent.libraryElementType))
    }
    
    public func handle(intent: PlayIDIntent, completion: @escaping (PlayIDIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSUserActivity.playIdActivityType)
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.id.rawValue: intent.id ?? ""])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.libraryElementType.rawValue: intent.libraryElementType.rawValue])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.shuffleOption.rawValue: intent.shuffleOption.rawValue])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.repeatOption.rawValue: intent.repeatOption.rawValue])
        let response = PlayIDIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}

public class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
    @available(iOS 13.0, *)
    public func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        completion(INPlayMediaMediaItemResolutionResult.successes(with: []))
    }

    @available(iOS 13.0, *)
    public func resolvePlayShuffled(for intent: INPlayMediaIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        completion(INBooleanResolutionResult.success(with: intent.playShuffled ?? false))
    }

    @available(iOS 13.0, *)
    public func resolvePlaybackRepeatMode(for intent: INPlayMediaIntent, with completion: @escaping (INPlaybackRepeatModeResolutionResult) -> Void) {
        completion(INPlaybackRepeatModeResolutionResult.success(with: intent.playbackRepeatMode))
    }
    
    @available(iOS 13.0, *)
    public func resolveResumePlayback(for intent: INPlayMediaIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        completion(INBooleanResolutionResult.success(with: intent.resumePlayback ?? true))
    }
    
    @available(iOS 13.0, *)
    public func resolvePlaybackQueueLocation(for intent: INPlayMediaIntent, with completion: @escaping (INPlaybackQueueLocationResolutionResult) -> Void) {
        completion(INPlaybackQueueLocationResolutionResult.success(with: intent.playbackQueueLocation))
    }

    @available(iOS 13.0, *)
    public func resolvePlaybackSpeed(for intent: INPlayMediaIntent, with completion: @escaping (INPlayMediaPlaybackSpeedResolutionResult) -> Void) {
        completion(INPlayMediaPlaybackSpeedResolutionResult.success(with: intent.playbackSpeed ?? 1.0))
    }

    public func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        // send intent to Amperfy App to analyse the intent and act accordingly
        completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
    }
}
