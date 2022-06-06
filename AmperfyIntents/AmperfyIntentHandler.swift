import Foundation
import Intents
import AmperfyKit

public class SearchAndPlayIntentHandler: NSObject, SearchAndPlayIntentHandling {
    @available(iOSApplicationExtension 13.0, *)
    public func resolveSearchCategory(for intent: SearchAndPlayIntent, with completion: @escaping (PlayableContainerTypeResolutionResult) -> Void) {
        completion(PlayableContainerTypeResolutionResult.success(with: intent.searchCategory))
    }
    
    public func handle(intent: SearchAndPlayIntent, completion: @escaping (SearchAndPlayIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSUserActivity.searchAndPlayActivityType)
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.searchTerm.rawValue: intent.searchTerm ?? ""])
        userActivity.addUserInfoEntries(from: [NSUserActivity.ActivityKeys.searchCategory.rawValue: intent.searchCategory.rawValue])
        let response = SearchAndPlayIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}
