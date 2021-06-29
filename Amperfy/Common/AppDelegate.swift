import UIKit
import MediaPlayer
import NotificationBanner

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
        return MusicPlayer(coreData: library.getPlayerData(), playableDownloadManager: playableDownloadManager, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
    }()
    lazy var playableDownloadManager: DownloadManager = {
        let requestManager = RequestManager()
        let dlDelegate = PlayableDownloadDelegate(backendApi: backendApi)
        let urlDownloader = UrlDownloader(requestManager: requestManager)
        let dlManager = DownloadManager(persistentStorage: persistentStorage, requestManager: requestManager, urlDownloader: urlDownloader, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        urlDownloader.urlDownloadNotifier = dlManager
        return dlManager
    }()
    lazy var artworkDownloadManager: DownloadManager = {
        let requestManager = RequestManager()
        let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
        let urlDownloader = UrlDownloader(requestManager: requestManager)
        let dlManager = DownloadManager(persistentStorage: persistentStorage, requestManager: requestManager, urlDownloader: urlDownloader, downloadDelegate: dlDelegate, eventLogger: eventLogger)
        urlDownloader.urlDownloadNotifier = dlManager
        return dlManager
    }()
    lazy var libraryUpdater = {
        return LibraryUpdater(persistentStorage: persistentStorage, backendApi: backendApi)
    }()
    lazy var userStatistics = {
        return library.getUserStatistics(appVersion: Self.version)
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
        self.player.configureRemoteCommands(commandCenter: MPRemoteCommandCenter.shared())
    }
    
    var isKeepScreenAlive: Bool {
        get { return UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSessionInterruptionAndRemoteControl()
        configureDefaultNavigationBarStyle()
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
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        if persistentStorage.loginCredentials != nil, persistentStorage.isLibrarySynced {
            artworkDownloadManager.stopAndWait()
            playableDownloadManager.stopAndWait()
        }
        library.saveContext()
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
        UIApplication.shared.keyWindow!.addSubview(banner)
        UIApplication.shared.keyWindow!.bringSubviewToFront(banner)
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
