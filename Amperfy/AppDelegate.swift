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

import AmperfyKit
import BackgroundTasks
import Intents
import MediaPlayer
import os.log
@preconcurrency import UIKit

let windowSettingsTitle = "Settings"
let windowMiniPlayerTitle = "MiniPlayer"

let settingsWindowActivityType = "amperfy.settings"
let miniPlayerWindowActivityType = "amperfy.miniplayer"
let defaultWindowActivityType = "amperfy.main"

// MARK: - AppDelegate

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  static let name = "Amperfy"
  static var version: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
  }

  static var buildNumber: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
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
    AmperKit.shared.log
  }()

  public lazy var storage = {
    AmperKit.shared.storage
  }()

  public var networkMonitor: NetworkMonitorFacade { AmperKit.shared.networkMonitor }

  public lazy var eventLogger: EventLogger = {
    AmperKit.shared.eventLogger
  }()

  public lazy var notificationHandler: EventNotificationHandler = {
    AmperKit.shared.notificationHandler
  }()

  public var libraryUpdater: LibraryUpdater { AmperKit.shared.libraryUpdater }

  public lazy var userStatistics = {
    AmperKit.shared.userStatistics
  }()

  public lazy var localNotificationManager = {
    AmperKit.shared.localNotificationManager
  }()

  public func getMeta(_ accountInfo: AccountInfo) -> MetaManager {
    AmperKit.shared.getMeta(accountInfo)
  }

  public func resetMeta(_ accountInfo: AccountInfo) {
    AmperKit.shared.resetMeta(accountInfo)
  }

  public lazy var intentManager = {
    IntentManager(
      storage: storage,
      getLibrarySyncerCB: { accountInfo in
        self.getMeta(accountInfo).librarySyncer
      },
      getPlayableDownloadManagerCB: { accountInfo in
        self.getMeta(accountInfo).playableDownloadManager
      },
      library: storage.main.library,
      getActiveAccountCallback: {
        guard let activeAccountInfo = self.storage.settings.accounts.active else { return nil }
        return self.storage.main.library.getAccount(info: activeAccountInfo)
      },
      player: player, networkMonitor: networkMonitor,
      eventLogger: eventLogger
    )
  }()

  public lazy var quickActionsManager = {
    QuickActionsHandler(
      storage: self.storage,
      player: self.player,
      application: UIApplication.shared,
      displaySearchTabCB: self.displaySearchTab
    )
  }()

  var settingsSceneSession: UISceneSession?
  var miniPlayerSceneSession: UISceneSession?

  var sleepTimer: Timer?

  var isKeepScreenAlive: Bool {
    get { UIApplication.shared.isIdleTimerDisabled }
    set { UIApplication.shared.isIdleTimerDisabled = newValue }
  }

  func configureDefaultNavigationBarStyle() {
    UINavigationBar.appearance().shadowImage = UIImage()
  }

  func configureBatteryMonitoring() {
    UIDevice.current.isBatteryMonitoringEnabled =
      (AmperKit.shared.storage.settings.user.screenLockPreventionPreference == .onlyIfCharging)
    configureLockScreenPrevention()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(batteryStateDidChange),
      name: UIDevice.batteryStateDidChangeNotification,
      object: nil
    )
  }

  @objc
  private func batteryStateDidChange(notification: NSNotification) {
    configureLockScreenPrevention()
  }

  func configureLockScreenPrevention() {
    os_log(
      "Device Battery Status: %s",
      log: self.log,
      type: .info,
      UIDevice.current.batteryState.description
    )
    switch AmperKit.shared.storage.settings.user.screenLockPreventionPreference {
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
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: Self.refreshTaskId,
      using: DispatchQueue.main
    ) { bgTask in
      Task { @MainActor in
        await self.performBackgroundFetchTask(bgTask: bgTask)
      }
    }
  }

  @MainActor
  private func performBackgroundFetchTask(bgTask: BGTask) async {
    os_log("Perform task: %s", log: self.log, type: .info, Self.refreshTaskId)
    var success = true
    for accountInfo in storage.settings.accounts.allAccounts {
      do {
        try await getMeta(accountInfo).backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes()
      } catch {
        success = false
        eventLogger.error(
          topic: "Background Task",
          statusCode: .connectionError,
          message: error.localizedDescription,
          displayPopup: false
        )
      }
    }
    bgTask.setTaskCompleted(success: success)
    userStatistics.backgroundFetchPerformed(result: UIBackgroundFetchResult.newData)
    scheduleAppRefresh()
  }

  func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 45 * 60) // Refresh after 45 minutes.
    do {
      // Submit only succeeds on real devices. On simulator it will always throw an error.
      try BGTaskScheduler.shared.submit(request)
    } catch {
      os_log(
        "Could not schedule app refresh task (%s) with error: %s",
        log: self.log,
        type: .error,
        Self.refreshTaskId,
        error.localizedDescription
      )
    }
  }

  func initEventLogger() {
    AmperKit.shared.eventLogger.alertDisplayer = self
  }

  func stopForInit() {
    sleepTimer?.invalidate()
    sleepTimer = nil
    player.stop()
  }

  // deprecated
  func restartByUser() {
    Task {
      await localNotificationManager.notifyDebugAndWait(
        title: "Amperfy Restart",
        body: "Tap to reopen Amperfy"
      )
      stopForInit()
      // close Amperfy
      exit(0)
    }
  }

  var isNormalInteraction: Bool {
    storage.settings.accounts.active != nil && !libraryUpdater
      .isVisualUpadateNeeded
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  )
    -> Bool {
    if let options = launchOptions {
      os_log("application launch with options:", log: self.log, type: .info)
      options
        .forEach { os_log("- key: %s", log: self.log, type: .info, $0.key.rawValue.description) }
    } else {
      os_log("application launch", log: self.log, type: .info)
    }

    storage.applyMultiAccountSettingsUpdateIfNeeded()
    libraryUpdater.performAccountCleanUpIfNeccessaryInBackground()

    configureDefaultNavigationBarStyle()
    configureBatteryMonitoring()
    configureBackgroundFetch()
    configureNotificationHandling()
    initEventLogger()

    guard let activeAccountInfo = appDelegate.storage.settings.accounts.active else {
      return true
    }

    setAppTheme(
      color: storage.settings.accounts.getSetting(activeAccountInfo).read.themePreference
        .asColor
    )

    guard AmperKit.shared.storage.settings.app.isLibrarySynced else {
      return true
    }

    os_log(
      "Amperfy Cache Location: %s",
      log: self.log,
      type: .info,
      CacheFileManager.shared.getAmperfyPath() ?? "-"
    )
    libraryUpdater.performSmallBlockingLibraryUpdatesIfNeeded()
    // start manager only if no visual indicated updates are needed
    if !libraryUpdater.isVisualUpadateNeeded {
      startManagerForNormalOperation()
    }
    userStatistics.sessionStarted()

    return true
  }

  private var isAlreadyRegisteredToPlayer = false
  func startManagerAfterSync() {
    os_log("Start background manager after sync", log: self.log, type: .info)
    configureMainMenu()
    intentManager.registerXCallbackURLs()
    if !isAlreadyRegisteredToPlayer {
      isAlreadyRegisteredToPlayer = true
      player.addNotifier(notifier: self)
    }
  }

  func startManagerForNormalOperation() {
    os_log("Start background manager for normal operation", log: self.log, type: .info)
    configureMainMenu()
    intentManager.registerXCallbackURLs()
    for accountInfo in storage.settings.accounts.allAccounts {
      getMeta(accountInfo).startManagerForNormalOperation(player: appDelegate.player)
    }
    isAlreadyRegisteredToPlayer = true
    player.addNotifier(notifier: self)
  }

  func setAppTheme(color: UIColor) {
    UIView.appearance().tintColor = color
  }

  // the following applies the tint color to already loaded views in all windows (UIKit)
  func applyAppThemeToAlreadyLoadedViews() {
    let windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = windowScene.flatMap { $0.windows }

    for window in windows {
      for view in window.subviews {
        view.removeFromSuperview()
        window.addSubview(view)
      }
    }
  }

  func switchAccount(accountInfo: AccountInfo) {
    storage.settings.accounts.switchActiveAccount(accountInfo)
    notificationHandler.post(
      name: .accountActiveChanged,
      object: nil,
      userInfo: nil
    )
    let account = appDelegate.storage.main.library.getAccount(info: accountInfo)

    closeAllButActiveMainTabs()
    setAppTheme(
      color: appDelegate.storage.settings.accounts.getSetting(accountInfo)
        .read.themePreference.asColor
    )
    applyAppThemeToAlreadyLoadedViews()
    AmperfyAppShortcuts.updateAppShortcutParameters()
    guard let mainScene = AppDelegate.mainSceneDelegate else { return }
    mainScene
      .replaceMainRootViewController(
        vc: AppStoryboard.Main
          .segueToMainWindow(account: account)
      )
  }

  func switchOnlineOfflineMode(isOfflineMode: Bool) {
    appDelegate.storage.settings.user.isOfflineMode = isOfflineMode
    appDelegate.notificationHandler.post(
      name: .offlineModeChanged,
      object: nil,
      userInfo: nil
    )
  }

  func setAppAppearanceMode(style: UIUserInterfaceStyle) {
    if #available(iOS 13.0, *) {
      UIApplication.shared.connectedScenes
        .forEach {
          if let windowScene = $0 as? UIWindowScene {
            windowScene.windows.forEach { window in
              window.overrideUserInterfaceStyle = style
              window.rootViewController?.overrideUserInterfaceStyle = style
            }
          }
        }
    }
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
    for meta in AmperKit.shared.allActiveMetas {
      meta.value.backgroundLibrarySyncer.stop()
    }
    storage.main.saveContext()
  }

  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @Sendable @escaping () -> ()
  ) {
    os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
    let responsibleMeta = AmperKit.shared.allActiveMetas
      .first(where: { $0.value.playableDownloadManager.urlSessionIdentifier == identifier })
    responsibleMeta?.value.playableDownloadManager
      .setBackgroundFetchCompletionHandler(completionHandler)
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  )
    -> UISceneConfiguration {
    guard connectingSceneSession.role != .carTemplateApplication else {
      let config = UISceneConfiguration(
        name: "CarPlay Configuration",
        sessionRole: .carTemplateApplication
      )
      config.delegateClass = CarPlaySceneDelegate.self
      return config
    }

    if options.userActivities.filter({ $0.activityType == settingsWindowActivityType })
      .first != nil {
      let config = UISceneConfiguration(name: "Settings", sessionRole: .windowApplication)
      config.delegateClass = SettingsSceneDelegate.self
      return config
    }

    if options.userActivities.filter({ $0.activityType == miniPlayerWindowActivityType })
      .first != nil {
      let config = UISceneConfiguration(name: "MiniPlayer", sessionRole: .windowApplication)
      config.delegateClass = MiniPlayerSceneDelegate.self
      return config
    }

    let config = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: .windowApplication
    )
    config.delegateClass = SceneDelegate.self
    return config
  }

  func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
    os_log("didDiscardSceneSessions", log: self.log, type: .info)
  }

  func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
    os_log("application handlerFor intent", log: self.log, type: .info)
    // This is the default implementation.  If you want different objects to handle different intents,
    // you can override this and return the handler you want for that particular intent.
    if intent is INPlayMediaIntent {
      return PlayMediaIntentHandler(intentManager: intentManager)
    }
    return nil
  }
}
