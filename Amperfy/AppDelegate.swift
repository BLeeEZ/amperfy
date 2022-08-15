import UIKit
import MediaPlayer
import BackgroundTasks
import os.log
import AmperfyKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let name = "Amperfy"
    static var version: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }
    static var buildNumber: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
    }
    /// Task IDs need to be added to the array in Info.list under: <key>BGTaskSchedulerPermittedIdentifiers</key>
    static let refreshTaskId = "de.familie-zimba.Amperfy.RefreshTask"
    
    var window: UIWindow?
    
    lazy var player: PlayerFacade = {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        return AmperKit.shared.player
    }()
    public lazy var log = {
        return AmperKit.shared.log
    }()
    public lazy var persistentStorage = {
        return AmperKit.shared.persistentStorage
    }()
    public lazy var library = {
        return AmperKit.shared.library
    }()
    public lazy var duplicateEntitiesResolver = {
        return AmperKit.shared.duplicateEntitiesResolver
    }()
    public lazy var eventLogger: EventLogger = {
        return AmperKit.shared.eventLogger
    }()
    public lazy var backendProxy: BackendProxy = {
        return AmperKit.shared.backendProxy
    }()
    public lazy var backendApi: BackendApi = {
        return AmperKit.shared.backendApi
    }()
    public lazy var notificationHandler: EventNotificationHandler = {
        return AmperKit.shared.notificationHandler
    }()
    public lazy var playableDownloadManager: DownloadManageable = {
        return AmperKit.shared.playableDownloadManager
    }()
    public lazy var artworkDownloadManager: DownloadManageable = {
        return AmperKit.shared.artworkDownloadManager
    }()
    public lazy var backgroundLibrarySyncer = {
        return AmperKit.shared.backgroundLibrarySyncer
    }()
    public lazy var scrobbleSyncer = {
        return AmperKit.shared.scrobbleSyncer
    }()
    public lazy var libraryUpdater = {
        return AmperKit.shared.libraryUpdater
    }()
    public lazy var userStatistics = {
        return AmperKit.shared.userStatistics
    }()
    public lazy var localNotificationManager = {
        return AmperKit.shared.localNotificationManager
    }()
    public lazy var backgroundFetchTriggeredSyncer = {
        return AmperKit.shared.backgroundFetchTriggeredSyncer
    }()
    public lazy var popupDisplaySemaphore = {
        return AmperKit.shared.popupDisplaySemaphore
    }()
    public lazy var carPlayHandler = {
        return AmperKit.shared.carPlayHandler
    }()
    public lazy var intentManager = {
        return AmperKit.shared.intentManager
    }()

    var isKeepScreenAlive: Bool {
        get { return UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }
    
    func configureBackgroundFetch() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
            os_log("Perform task: %s", log: self.log, type: .info, Self.refreshTaskId)
            self.backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes() { fetchResult in
                self.userStatistics.backgroundFetchPerformed(result: fetchResult)
                task.setTaskCompleted(success: true)
                self.scheduleAppRefresh()
            }
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 45 * 60) // Refresh after 45 minutes.
        do {
            // Submit only succeeds on real devices. On simulator it will always throw an error.
            try BGTaskScheduler.shared.submit(request)
        } catch {
            os_log("Could not schedule app refresh task (%s) with error: %s", log: self.log, type: .error, Self.refreshTaskId, error.localizedDescription)
        }
    }
    
    func initEventLogger() {
        AmperKit.shared.eventLogger.alertDisplayer = self
    }
    
    func reinit() {
        AmperKit.shared.reinit()
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        os_log("application launch via userActivity: %s", log: self.log, type: .info, userActivity.activityType)
        return intentManager.handleIncomingIntent(userActivity: userActivity)
    }

    /// Open the app when opened via URL scheme
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {
        return intentManager.handleIncoming(url: url)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let options = launchOptions {
            os_log("application launch with options:", log: self.log, type: .info)
            options.forEach{ os_log("- key: %s", log: self.log, type: .info, $0.key.rawValue.description) }
        } else {
            os_log("application launch", log: self.log, type: .info)
        }

        configureDefaultNavigationBarStyle()
        configureBackgroundFetch()
        configureNotificationHandling()
        initEventLogger()
        intentManager.registerXCallbackURLs()
        self.window = MainWindow(frame: UIScreen.main.bounds)
        
        guard let credentials = persistentStorage.loginCredentials else {
            let initialViewController = LoginVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backendProxy.selectedApi = credentials.backendApi
        backendApi.provideCredentials(credentials: credentials)
        
        guard AmperKit.shared.persistentStorage.isLibrarySynced else {
            let initialViewController = SyncVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        libraryUpdater.performBlockingLibraryUpdatesIfNeeded()
        duplicateEntitiesResolver.start()
        artworkDownloadManager.start()
        playableDownloadManager.start()
        backgroundLibrarySyncer.start()
        scrobbleSyncer.start()
        userStatistics.sessionStarted()
        carPlayHandler.initialize()
        let initialViewController = TabBarVC.instantiateFromAppStoryboard()
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        os_log("applicationWillResignActive", log: self.log, type: .info)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        os_log("applicationDidEnterBackground", log: self.log, type: .info)
        self.scheduleAppRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        os_log("applicationWillEnterForeground", log: self.log, type: .info)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        os_log("applicationDidBecomeActive", log: self.log, type: .info)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        os_log("applicationWillTerminate", log: self.log, type: .info)
        backgroundLibrarySyncer.stopAndWait()
        library.saveContext()
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
        playableDownloadManager.backgroundFetchCompletionHandler = completionHandler
    }
    
}
