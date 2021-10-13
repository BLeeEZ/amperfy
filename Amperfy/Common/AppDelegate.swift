import UIKit
import MediaPlayer
import NotificationBanner
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let name = "Amperfy"
    static var version: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }
    static var buildNumber: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
    }
    
    var window: UIWindow?

    lazy var log = {
        return OSLog(subsystem: AppDelegate.name, category: "AppDelegate")
    }()
    lazy var persistentStorage = {
        return PersistentStorage()
    }()
    lazy var library = {
        return LibraryStorage(context: persistentStorage.context)
    }()
    lazy var eventLogger = {
        return EventLogger(alertDisplayer: self, persistentContainer: persistentStorage.persistentContainer)
    }()
    lazy var backendProxy: BackendProxy = {
        return BackendProxy(eventLogger: eventLogger)
    }()
    lazy var backendApi: BackendApi = {
        return backendProxy
    }()
    lazy var player: MusicPlayer = {
        let backendAudioPlayer = BackendAudioPlayer(mediaPlayer: AVPlayer(), eventLogger: eventLogger, backendApi: backendApi, playableDownloader: playableDownloadManager, cacheProxy: library, userStatistics: userStatistics)
        let curPlayer = MusicPlayer(coreData: library.getPlayerData(), playableDownloadManager: playableDownloadManager, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
        curPlayer.isOfflineMode = persistentStorage.settings.isOfflineMode
        return curPlayer
    }()
    lazy var playableDownloadManager: DownloadManageable = {
        let dlDelegate = PlayableDownloadDelegate(backendApi: backendApi)
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        let dlManager = DownloadManager(name: "PlayableDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).PlayableDownloader.background")
        var urlSession = URLSession(configuration: configuration, delegate: dlManager, delegateQueue: nil)
        dlManager.urlSession = urlSession
        
        return dlManager
    }()
    lazy var artworkDownloadManager: DownloadManageable = {
        let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        requestManager.clearAllDownloads()
        let dlManager = DownloadManager(name: "ArtworkDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        
        let configuration = URLSessionConfiguration.default
        var urlSession = URLSession(configuration: configuration, delegate: dlManager, delegateQueue: nil)
        dlManager.urlSession = urlSession
        
        return dlManager
    }()
    lazy var libraryUpdater = {
        return LibraryUpdater(persistentStorage: persistentStorage, backendApi: backendApi)
    }()
    lazy var userStatistics = {
        return library.getUserStatistics(appVersion: Self.version)
    }()
    lazy var localNotificationManager = {
        return LocalNotificationManager(userStatistics: userStatistics)
    }()
    lazy var backgroundFetchTriggeredSyncer = {
        return BackgroundFetchTriggeredSyncer(library: library, backendApi: backendApi, notificationManager: localNotificationManager)
    }()
    private lazy var popupDisplaySemaphore = {
        return DispatchSemaphore(value: 1)
    }()

    func reinit() {
        player.reinit(coreData: library.getPlayerData())
    }

    func configureAudioSessionInterruptionAndRemoteControl() {
        self.player.configureObserverForAudioSessionInterruption(audioSession: AVAudioSession.sharedInstance())
        self.player.configureBackgroundPlayback(audioSession: AVAudioSession.sharedInstance())
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.player.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        self.player.configureRemoteCommands(remoteCommandCenter: MPRemoteCommandCenter.shared())
    }
    
    var isKeepScreenAlive: Bool {
        get { return UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }
    
    func configureBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    func configureNotificationHandling() {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let options = launchOptions {
            os_log("application launch with options:", log: self.log, type: .info)
            options.forEach{ os_log("- key: %s", log: self.log, type: .info, $0.key.rawValue.description) }
        } else {
            os_log("application launch", log: self.log, type: .info)
        }

        configureAudioSessionInterruptionAndRemoteControl()
        configureDefaultNavigationBarStyle()
        configureBackgroundFetch()
        configureNotificationHandling()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        guard let credentials = persistentStorage.loginCredentials else {
            let initialViewController = LoginVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backendProxy.selectedApi = credentials.backendApi
        backendApi.provideCredentials(credentials: credentials)
        
        guard persistentStorage.isLibrarySynced else {
            let initialViewController = SyncVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        libraryUpdater.performBlockingLibraryUpdatesIfNeeded()
        artworkDownloadManager.start()
        playableDownloadManager.start()
        userStatistics.sessionStarted()
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
        library.saveContext()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("performFetchWithCompletionHandler", log: self.log, type: .info)
        let fetchResult = backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes()
        userStatistics.backgroundFetchPerformed(result: fetchResult)
        completionHandler(fetchResult)
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
        playableDownloadManager.backgroundFetchCompletionHandler = completionHandler
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate
{
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        userStatistics.appStartedViaNotification()
        let userInfo = response.notification.request.content.userInfo
        guard let contentTypeRaw = userInfo[NotificationUserInfo.type] as? NSString, let contentType = NotificationContentType(rawValue: contentTypeRaw), let id = userInfo[NotificationUserInfo.id] as? String else { completionHandler(); return }

        switch contentType {
        case .podcastEpisode:
            let episode = library.getPodcastEpisode(id: id)
            if let podcast = episode?.podcast {
                let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
                podcastDetailVC.podcast = podcast
                displayInLibraryTab(vc: podcastDetailVC)
            }
        }
        completionHandler()
    }
    
    private func displayInLibraryTab(vc: UIViewController) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              let hostingTabBarVC = topView as? UITabBarController
        else { return }
        
        if hostingTabBarVC.popupPresentationState == .open,
           let popupPlayerVC = hostingTabBarVC.popupContent as? PopupPlayerVC {
            popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: vc)
        } else if let hostingTabViewControllers = hostingTabBarVC.viewControllers,
           hostingTabViewControllers.count > 0,
           let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
            libraryTabNavVC.pushViewController(vc, animated: false)
            hostingTabBarVC.selectedIndex = 0
        }
    }
}

extension AppDelegate {
    static func topViewController(base: UIViewController? = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController) -> UIViewController? {
        if base?.presentedViewController is UIAlertController {
            return base
        }
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return tab
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

/// Must be called from main thread
protocol AlertDisplayable {
    func display(notificationBanner popupVC: LibrarySyncPopupVC)
    func display(popup popupVC: LibrarySyncPopupVC)
}

extension AppDelegate: AlertDisplayable {
    func display(notificationBanner popupVC: LibrarySyncPopupVC) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil
              else { return }

        let banner = FloatingNotificationBanner(title: popupVC.topic, subtitle: popupVC.message, style: BannerStyle.from(logType: popupVC.logType), colors: AmperfyBannerColors())
        
        banner.onTap = {
            self.display(popup: popupVC)
        }
        
        banner.show(queuePosition: .back, bannerPosition: .top, on: topView, cornerRadius: 20, shadowBlurRadius: 10)
        if let keyWindow = UIApplication.shared.keyWindow {
            keyWindow.addSubview(banner)
            keyWindow.bringSubviewToFront(banner)
        }
    }
    
    func display(popup popupVC: LibrarySyncPopupVC) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              self.popupDisplaySemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 0)) == .success
              else { return }
        popupVC.onClose = {
            self.popupDisplaySemaphore.signal()
        }
        popupVC.modalPresentationStyle = .overCurrentContext
        popupVC.modalTransitionStyle = .crossDissolve
        topView.present(popupVC, animated: true, completion: nil)
    }
}
