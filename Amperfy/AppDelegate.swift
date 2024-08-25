//
//  AppDelegate.swift
//  Amperfy
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

import UIKit
import MediaPlayer
import BackgroundTasks
import os.log
import AmperfyKit
import PromiseKit
import Intents

let windowSettingsTitle = "Settings"
let windowMiniPlayerTitle = "MiniPlayer"

let settingsWindowActivityType = "amperfy.settings"
let miniPlayerWindowActivityType = "amperfy.miniplayer"
let defaultWindowActivityType = "amperfy.main"

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
    
    static let maxPlayablesDownloadsToAddAtOnceWithoutWarning = 200
    
    var window: UIWindow?
    var focusedWindowTitle: String?

    lazy var player: PlayerFacade = {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        return AmperKit.shared.player
    }()
    public lazy var log = {
        return AmperKit.shared.log
    }()
    public lazy var storage = {
        return AmperKit.shared.storage
    }()
    public lazy var networkMonitor = {
        return AmperKit.shared.networkMonitor
    }()
    public lazy var librarySyncer = {
        return AmperKit.shared.librarySyncer
    }()
    public lazy var duplicateEntitiesResolver = {
        return AmperKit.shared.duplicateEntitiesResolver
    }()
    public lazy var eventLogger: EventLogger = {
        return AmperKit.shared.eventLogger
    }()
    public lazy var backendApi: BackendProxy = {
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
    public lazy var intentManager = {
        return IntentManager(storage: storage, librarySyncer: librarySyncer, playableDownloadManager: playableDownloadManager, library: storage.main.library, player: player)
    }()
    public lazy var quickActionsManager = {
        return QuickActionsHandler(storage: self.storage, player: self.player, application: UIApplication.shared, displaySearchTabCB: self.displaySearchTab)
    }()
    
    var settingsSceneSession: UISceneSession?
    var miniPlayerSceneSession: UISceneSession?

    var sleepTimer: Timer?
    var autoActivateSearchTabSearchBar = false

    var isKeepScreenAlive: Bool {
        get { return UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    
    func configureDefaultNavigationBarStyle() {
        UINavigationBar.appearance().shadowImage = UIImage()
    }
    
    func configureBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled =
            (AmperKit.shared.storage.settings.screenLockPreventionPreference == .onlyIfCharging)
        configureLockScreenPrevention()
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }
    
    @objc private func batteryStateDidChange(notification: NSNotification) {
        configureLockScreenPrevention()
    }
    
    func configureLockScreenPrevention() {
        os_log("Device Battery Status: %s", log: self.log, type: .info, UIDevice.current.batteryState.description)
        switch(AmperKit.shared.storage.settings.screenLockPreventionPreference) {
        case .always:
            isKeepScreenAlive = true
        case .never:
            isKeepScreenAlive = false
        case .onlyIfCharging:
            isKeepScreenAlive = UIDevice.current.batteryState != .unplugged
        }
        os_log("Lock Screen Prevention: %s", log: self.log, type: .info, isKeepScreenAlive.description)
    }
    
    func configureBackgroundFetch() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
            os_log("Perform task: %s", log: self.log, type: .info, Self.refreshTaskId)
            firstly {
                self.backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes()
            }.done {
                task.setTaskCompleted(success: true)
            }.catch { error in
                task.setTaskCompleted(success: false)
                self.eventLogger.error(topic: "Background Task", statusCode: .connectionError, message: error.localizedDescription, displayPopup: false)
            }.finally {
                self.userStatistics.backgroundFetchPerformed(result: UIBackgroundFetchResult.newData)
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
    
    func restartByUser() {
        LocalNotificationManager.notifyDebug(title: "Amperfy Restart", body: "Tap to reopen Amperfy")
        sleepTimer?.invalidate()
        sleepTimer = nil
        player.stop()
        // Wait some time to let the notification appear
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1500000)) {
            // close Amperfy
            exit(0)
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let options = launchOptions {
            os_log("application launch with options:", log: self.log, type: .info)
            options.forEach{ os_log("- key: %s", log: self.log, type: .info, $0.key.rawValue.description) }
        } else {
            os_log("application launch", log: self.log, type: .info)
        }

        AmperKit.shared.networkMonitor.start()
        configureDefaultNavigationBarStyle()
        configureBatteryMonitoring()
        configureBackgroundFetch()
        configureNotificationHandling()
        initEventLogger()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        guard let credentials = storage.loginCredentials else {
            return true
        }
        
        setAppTheme(color: storage.settings.themePreference.asColor)
        
        backendApi.selectedApi = credentials.backendApi
        backendApi.provideCredentials(credentials: credentials)
        
        guard AmperKit.shared.storage.isLibrarySynced else {
            return true
        }
        
        os_log("Amperfy Cache Location: %s", log: self.log, type: .info, CacheFileManager.shared.getAmperfyPath() ?? "-")
        libraryUpdater.performSmallBlockingLibraryUpdatesIfNeeded()
        // start manager only if no visual indicated updates are needed
        if !libraryUpdater.isVisualUpadateNeeded {
            startManagerForNormalOperation()
        }
        userStatistics.sessionStarted()

        #if targetEnvironment(macCatalyst)

        AppDelegate.loadAppKitIntegrationFramework()
        AppDelegate.installAppKitColorHooks()
        
        // update color of AppKit controls
        AppDelegate.updateAppKitControlColor()

        // whenever we change the window focus, we rebuild the menu
        NotificationCenter.default.addObserver(forName: .init("NSWindowDidBecomeMainNotification"), object: nil, queue: nil) { [weak self] notification in
            
            self?.focusedWindowTitle = (notification.object as? AnyObject)?.value(forKey: "title") as? String
            UIMenuSystem.main.setNeedsRebuild()
        }
        #endif

        return true
    }
    
    func startManagerAfterSync() {
        os_log("Start background manager after sync", log: self.log, type: .info)
        intentManager.registerXCallbackURLs()
        playableDownloadManager.start()
        artworkDownloadManager.start()
        backgroundLibrarySyncer.start()
    }
    
    func startManagerForNormalOperation() {
        os_log("Start background manager for normal operation", log: self.log, type: .info)
        intentManager.registerXCallbackURLs()
        duplicateEntitiesResolver.start()
        artworkDownloadManager.start()
        playableDownloadManager.start()
        backgroundLibrarySyncer.start()
        scrobbleSyncer?.start()
    }
    
    func setAppTheme(color: UIColor) {
        UIView.appearance().tintColor = color
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
        backgroundLibrarySyncer.stopAndWait()
        storage.main.saveContext()
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
        playableDownloadManager.backgroundFetchCompletionHandler = completionHandler
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        guard connectingSceneSession.role != .carTemplateApplication else {
            let config = UISceneConfiguration(name: "CarPlay Configuration", sessionRole: .carTemplateApplication)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        // Support setting window on macOS
        #if targetEnvironment(macCatalyst)
        if options.userActivities.filter({$0.activityType == settingsWindowActivityType}).first != nil {
            let config =  UISceneConfiguration(name: "Settings", sessionRole: .windowApplication)
            config.delegateClass = SettingsSceneDelegate.self
            return config
        }

        if options.userActivities.filter({$0.activityType == miniPlayerWindowActivityType}).first != nil {
            let config =  UISceneConfiguration(name: "MiniPlayer", sessionRole: .windowApplication)
            config.delegateClass = MiniPlayerSceneDelegate.self
            return config
        }
        #endif

        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: .windowApplication)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        os_log("didDiscardSceneSessions", log: self.log, type: .info)
    }

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        os_log("application handlerFor intent", log: self.log, type: .info)
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        if intent is SearchAndPlayIntent {
            return SearchAndPlayIntentHandler(intentManager: intentManager)
        }
        if intent is PlayIDIntent {
            return PlayIDIntentHandler(intentManager: intentManager)
        }
        if intent is INPlayMediaIntent {
            return PlayMediaIntentHandler(intentManager: intentManager)
        }
        return nil
    }

    func closeMainWindow() {
        guard let sceneSession = self.window?.windowScene?.session else { return }

        let options = UIWindowSceneDestructionRequestOptions()
        options.windowDismissalAnimation = .standard

        UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: nil)
    }

    func openMainWindow() {
        let defaultActivity = NSUserActivity(activityType: defaultWindowActivityType)
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: defaultActivity, options: nil, errorHandler: nil)
    }

    #if targetEnvironment(macCatalyst)

    override func buildMenu(with builder: any UIMenuBuilder) {
        // TODO: Add option to restore main window / aka show the main window. There must only ever be a single instance of the window

        super.buildMenu(with: builder)

        guard builder.system == .main else { return }

        // Add a settings menu
        let settingsMenu = UIMenu(options: .displayInline, children: [
           UIKeyCommand(title: "Settings…", action: #selector(showSettings), input: ",", modifierFlags: .command)
        ])
        builder.insertSibling(settingsMenu, afterMenu: .about)
        builder.remove(menu: .toolbar)

        // Multi-window does not work, so remove it.
        builder.remove(menu: .newScene)

        if (self.focusedWindowTitle == windowSettingsTitle) || (self.focusedWindowTitle == windowMiniPlayerTitle)  {
            // Do any settings specific menu setup here
            builder.remove(menu: .view)
        } else {
            builder.remove(menu: .sidebar)
        }
    }

    @objc func showSettings(sender: Any) {
        let settingsActivity = NSUserActivity(activityType: settingsWindowActivityType)
        UIApplication.shared.requestSceneSessionActivation(settingsSceneSession, userActivity: settingsActivity, options: nil, errorHandler: nil)
    }

    @objc func showMiniPlayer(sender: Any? = nil) {
        let miniPlayerActivity = NSUserActivity(activityType: miniPlayerWindowActivityType)
        UIApplication.shared.requestSceneSessionActivation(miniPlayerSceneSession, userActivity: miniPlayerActivity, options: nil, errorHandler: nil)
    }
    #endif
}
