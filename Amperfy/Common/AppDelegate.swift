import UIKit
import MediaPlayer
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
    lazy var notificationHandler: EventNotificationHandler = {
        return EventNotificationHandler()
    }()
    lazy var player: PlayerFacade = {
        let backendAudioPlayer = BackendAudioPlayer(mediaPlayer: AVPlayer(), eventLogger: eventLogger, backendApi: backendApi, playableDownloader: playableDownloadManager, cacheProxy: library, userStatistics: userStatistics)
        let playerData = library.getPlayerData()
        let queueHandler = PlayQueueHandler(playerData: playerData)
        let curPlayer = MusicPlayer(coreData: playerData, queueHandler: queueHandler, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
        
        let playerDownloadPreparationHandler = PlayerDownloadPreparationHandler(playerStatus: playerData, queueHandler: queueHandler, playableDownloadManager: playableDownloadManager)
        curPlayer.addNotifier(notifier:  playerDownloadPreparationHandler)
        let songPlayedSyncer = SongPlayedSyncer(persistentStorage: persistentStorage, musicPlayer: curPlayer, backendAudioPlayer: backendAudioPlayer, backendApi: backendApi)
        curPlayer.addNotifier(notifier: songPlayedSyncer)

        let facadeImpl = PlayerFacadeImpl(playerStatus: playerData, queueHandler: queueHandler, musicPlayer: curPlayer, library: library, playableDownloadManager: playableDownloadManager, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
        facadeImpl.isOfflineMode = persistentStorage.settings.isOfflineMode
        
        let audioSessionHandler = AudioSessionHandler(musicPlayer: curPlayer)
        audioSessionHandler.configureObserverForAudioSessionInterruption(audioSession: AVAudioSession.sharedInstance())
        audioSessionHandler.configureBackgroundPlayback(audioSession: AVAudioSession.sharedInstance())
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let nowPlayingInfoCenterHandler = NowPlayingInfoCenterHandler(musicPlayer: curPlayer, backendAudioPlayer: backendAudioPlayer, nowPlayingInfoCenter: MPNowPlayingInfoCenter.default(), persistentStorage: persistentStorage)
        curPlayer.addNotifier(notifier: nowPlayingInfoCenterHandler)
        let remoteCommandCenterHandler = RemoteCommandCenterHandler(musicPlayer: facadeImpl, backendAudioPlayer: backendAudioPlayer, remoteCommandCenter: MPRemoteCommandCenter.shared())
        remoteCommandCenterHandler.configureRemoteCommands()
        curPlayer.addNotifier(notifier: remoteCommandCenterHandler)

        return facadeImpl
    }()
    lazy var playableDownloadManager: DownloadManageable = {
        let artworkExtractor = EmbeddedArtworkExtractor()
        let dlDelegate = PlayableDownloadDelegate(backendApi: backendApi, artworkExtractor: artworkExtractor)
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        let dlManager = DownloadManager(name: "PlayableDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, notificationHandler: notificationHandler, eventLogger: eventLogger)
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).PlayableDownloader.background")
        var urlSession = URLSession(configuration: configuration, delegate: dlManager, delegateQueue: nil)
        dlManager.urlSession = urlSession
        
        return dlManager
    }()
    lazy var artworkDownloadManager: DownloadManageable = {
        let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        requestManager.clearAllDownloads()
        let dlManager = DownloadManager(name: "ArtworkDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, notificationHandler: notificationHandler, eventLogger: eventLogger)
        dlManager.isFailWithPopupError = false
        
        dlManager.preDownloadIsValidCheck = { object in
            guard let artwork = object as? Artwork else { return false }
            switch self.persistentStorage.settings.artworkDownloadSetting {
            case .updateOncePerSession:
                return true
            case .onlyOnce:
                switch artwork.status {
                case .NotChecked, .FetchError:
                    return true
                case .IsDefaultImage, .CustomImage:
                    return false
                }
            case .never:
                return false
            }
        }
        
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
        return LocalNotificationManager(userStatistics: userStatistics, persistentStorage: persistentStorage)
    }()
    lazy var backgroundFetchTriggeredSyncer = {
        return BackgroundFetchTriggeredSyncer(persistentStorage: persistentStorage, backendApi: backendApi, notificationManager: localNotificationManager)
    }()
    lazy var popupDisplaySemaphore = {
        return DispatchSemaphore(value: 1)
    }()
    lazy var carPlayHandler = {
        return CarPlayHandler(persistentStorage: self.persistentStorage, library: self.library, backendApi: self.backendApi, player: self.player, playableContentManager: MPPlayableContentManager.shared())
    }()

    func reinit() {
        let playerData = library.getPlayerData()
        let queueHandler = PlayQueueHandler(playerData: playerData)
        player.reinit(playerStatus: playerData, queueHandler: queueHandler)
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
        backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes() { fetchResult in
            self.userStatistics.backgroundFetchPerformed(result: fetchResult)
            completionHandler(fetchResult)
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
        playableDownloadManager.backgroundFetchCompletionHandler = completionHandler
    }
    
}
