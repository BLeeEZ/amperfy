import UIKit
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let name = "Amperfy"
    var window: UIWindow?

    lazy var storage = {
        return PersistentStorage()
    }()
    lazy var persistentLibraryStorage = {
        return LibraryStorage(context: storage.context)
    }()
    lazy var backendApi: BackendApi = {
        return AmpacheApi(ampacheXmlServerApi: AmpacheXmlServerApi())
    }()
    lazy var library = {
        return Library(storage: persistentLibraryStorage)
    }()
    lazy var player = {
        return Player(coreData: persistentLibraryStorage.getPlayerData(), ampachePlayer: AmpachePlayer(downloadManager: downloadManager))
    }()
    lazy var downloadManager: DownloadManager = {
        let requestManager = RequestManager()
        let dlDelegate = DownloadDelegate(backendApi: backendApi)
        let urlDownloader = UrlDownloader(requestManager: requestManager)
        let dlManager = DownloadManager(storage: storage, requestManager: requestManager, urlDownloader: urlDownloader, downloadDelegate: dlDelegate)
        urlDownloader.urlDownloadNotifier = dlManager
        return dlManager
    }()
    lazy var backgroundSyncer = {
        return BackgroundSyncer(storage: storage, backendApi: backendApi)
    }()

    func reinit() {
        player.reinit(coreData: persistentLibraryStorage.getPlayerData())
    }

    func configureRemoteControl() {
        self.player.configureBackgroundPlayback(audioSession: AVAudioSession.sharedInstance())
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.player.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        self.player.configureRemoteCommands(commandCenter: MPRemoteCommandCenter.shared())
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureRemoteControl()
        configureDefaultNavigationBarStyle()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        guard let credentials = storage.getLoginCredentials() else {
            let initialViewController = LoginVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backendApi.provideCredentials(credentials: credentials)
        
        guard storage.isAmpacheSynced() else {
            let initialViewController = SyncVC.instantiateFromAppStoryboard()
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
            return true
        }
        backgroundSyncer.start()
    
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
        guard storage.getLoginCredentials() != nil, storage.isAmpacheSynced() else { return }
        backgroundSyncer.stop()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if storage.isAmpacheSynced() {
            backgroundSyncer.start()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        persistentLibraryStorage.saveContext()
    }


}

