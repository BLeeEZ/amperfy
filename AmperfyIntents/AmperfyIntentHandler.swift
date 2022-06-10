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
