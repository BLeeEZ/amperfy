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
