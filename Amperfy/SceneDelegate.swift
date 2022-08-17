import UIKit
import OSLog
import AmperfyKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    public lazy var appDelegate = {
        return UIApplication.shared.delegate as! AppDelegate
    }()
    public lazy var log = {
        return AmperKit.shared.log
    }()
    
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        os_log("willConnectTo", log: self.log, type: .info)
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = scene as? UIWindowScene else { return }
        self.window = UIWindow(windowScene: windowScene)
        self.appDelegate.window = self.window
        var initialViewController: UIViewController?
        
        if AmperKit.shared.persistentStorage.loginCredentials == nil {
            initialViewController = LoginVC.instantiateFromAppStoryboard()
        } else if !AmperKit.shared.persistentStorage.isLibrarySynced {
            initialViewController = SyncVC.instantiateFromAppStoryboard()
        } else {
            initialViewController = TabBarVC.instantiateFromAppStoryboard()
        }
        
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
    }
    
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        os_log("sceneDidDisconnect", log: self.log, type: .info)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        os_log("sceneDidBecomeActive", log: self.log, type: .info)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        os_log("sceneWillResignActive", log: self.log, type: .info)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        os_log("sceneWillEnterForeground", log: self.log, type: .info)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        os_log("sceneDidEnterBackground", log: self.log, type: .info)
        self.appDelegate.scheduleAppRefresh()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        os_log("openURLContexts", log: self.log, type: .info)
        for URLContext in URLContexts {
            _ = self.appDelegate.intentManager.handleIncoming(url: URLContext.url)
        }
    }

    // This is the NSUserActivity that will be used to restore state when the Scene reconnects.
    // It can be the same activity used for handoff or spotlight, or it can be a separate activity
    // with a different activity type and/or userInfo.
    // After this method is called, and before the activity is actually saved in the restoration file,
    // if the returned NSUserActivity has a delegate (NSUserActivityDelegate), the method
    // userActivityWillSave is called on the delegate. Additionally, if any UIResponders
    // have the activity set as their userActivity property, the UIResponder updateUserActivityState
    // method is called to update the activity. This is done synchronously and ensures the activity
    // has all info filled in before it is saved.
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        os_log("stateRestorationActivity", log: self.log, type: .info)
        return nil
    }

    
    // This will be called after scene connection, but before activation, and will provide the
    // activity that was last supplied to the stateRestorationActivityForScene callback, or
    // set on the UISceneSession.stateRestorationActivity property.
    // Note that, if it's required earlier, this activity is also already available in the
    // UISceneSession.stateRestorationActivity at scene connection time.
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        os_log("restoreInteractionStateWith", log: self.log, type: .info)
    }

    
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        os_log("willContinueUserActivityWithType", log: self.log, type: .info)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        os_log("scene launch via userActivity: %s", log: self.log, type: .info, userActivity.activityType)
        _ = appDelegate.intentManager.handleIncomingIntent(userActivity: userActivity)
    }

    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        os_log("didFailToContinueUserActivityWithType", log: self.log, type: .info)
    }

    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        os_log("didUpdate userActivity", log: self.log, type: .info)
    }
    
}
