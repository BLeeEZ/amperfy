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

  public var librarySyncer: LibrarySyncer { AmperKit.shared.librarySyncer }

  public lazy var duplicateEntitiesResolver = {
    AmperKit.shared.duplicateEntitiesResolver
  }()

  public lazy var eventLogger: EventLogger = {
    AmperKit.shared.eventLogger
  }()

  public var backendApi: BackendProxy { AmperKit.shared.backendApi }

  public lazy var notificationHandler: EventNotificationHandler = {
    AmperKit.shared.notificationHandler
  }()

  public lazy var playableDownloadManager: DownloadManageable = {
    AmperKit.shared.playableDownloadManager
  }()

  public lazy var artworkDownloadManager: DownloadManageable = {
    AmperKit.shared.artworkDownloadManager
  }()

  public lazy var backgroundLibrarySyncer = {
    AmperKit.shared.backgroundLibrarySyncer
  }()

  public lazy var scrobbleSyncer = {
    AmperKit.shared.scrobbleSyncer
  }()

  public var libraryUpdater: LibraryUpdater { AmperKit.shared.libraryUpdater }

  public lazy var userStatistics = {
    AmperKit.shared.userStatistics
  }()

  public lazy var localNotificationManager = {
    AmperKit.shared.localNotificationManager
  }()

  public var backgroundFetchTriggeredSyncer: BackgroundFetchTriggeredSyncer {
    AmperKit.shared.backgroundFetchTriggeredSyncer
  }

  public lazy var intentManager = {
    IntentManager(
      storage: storage,
      librarySyncer: librarySyncer,
      playableDownloadManager: playableDownloadManager,
      library: storage.main.library,
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
  var autoActivateSearchTabSearchBar = false

  var isKeepScreenAlive: Bool {
    get { UIApplication.shared.isIdleTimerDisabled }
    set { UIApplication.shared.isIdleTimerDisabled = newValue }
  }

  func configureDefaultNavigationBarStyle() {
    UINavigationBar.appearance().shadowImage = UIImage()
  }

  func configureBatteryMonitoring() {
    UIDevice.current.isBatteryMonitoringEnabled =
      (AmperKit.shared.storage.settings.screenLockPreventionPreference == .onlyIfCharging)
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
    switch AmperKit.shared.storage.settings.screenLockPreventionPreference {
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
    do {
      try await backgroundFetchTriggeredSyncer.syncAndNotifyPodcastEpisodes()
      bgTask.setTaskCompleted(success: true)
    } catch {
      bgTask.setTaskCompleted(success: false)
      eventLogger.error(
        topic: "Background Task",
        statusCode: .connectionError,
        message: error.localizedDescription,
        displayPopup: false
      )
    }
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

  func reinit() {
    AmperKit.shared.reinit()
  }

  func restartByUser() {
    Task {
      await localNotificationManager.notifyDebugAndWait(
        title: "Amperfy Restart",
        body: "Tap to reopen Amperfy"
      )
      sleepTimer?.invalidate()
      sleepTimer = nil
      player.stop()
      // close Amperfy
      exit(0)
    }
  }

  #if targetEnvironment(macCatalyst)
    @objc
    private func padStyle() -> UIBehavioralStyle {
      .pad
    }

    private func patchMPVolumeViewPreSonoma() {
      // we must always force .pad style for MPVolumeSlider below MacOS 17. Otherwise the App crashes
      if #unavailable(macCatalyst 17.0) {
        let originalClass: AnyClass? = NSClassFromString("MPVolumeSlider")
        let originalSelector = NSSelectorFromString("preferredBehavioralStyle")
        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzleMethod = class_getInstanceMethod(
                AppDelegate.self,
                #selector(self.padStyle)
              )
        else { return }
        method_exchangeImplementations(originalMethod, swizzleMethod)
      }
    }
  #endif

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

    configureDefaultNavigationBarStyle()
    configureBatteryMonitoring()
    configureBackgroundFetch()
    configureNotificationHandling()
    initEventLogger()
    window = UIWindow(frame: UIScreen.main.bounds)

    #if targetEnvironment(macCatalyst)
      patchMPVolumeViewPreSonoma()

      AppDelegate.loadAppKitIntegrationFramework()
      AppDelegate.installAppKitColorHooks()

      // update color of AppKit controls
      AppDelegate.updateAppKitControlColor(storage.settings.themePreference.asColor)

      // whenever we change the window focus, we rebuild the menu
      NotificationCenter.default.addObserver(
        forName: .init("NSWindowDidBecomeMainNotification"),
        object: nil,
        queue: nil
      ) { [weak self] notification in
        let focusedWindowTitle = (notification.object as? AnyObject)?
          .value(forKey: "title") as? String
        Task { @MainActor in
          self?.focusedWindowTitle = focusedWindowTitle
          UIMenuSystem.main.setNeedsRebuild()
        }
      }
    #endif

    guard let credentials = storage.loginCredentials else {
      return true
    }

    setAppTheme(color: storage.settings.themePreference.asColor)

    backendApi.selectedApi = credentials.backendApi
    backendApi.provideCredentials(credentials: credentials)

    guard AmperKit.shared.storage.isLibrarySynced else {
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

  func startManagerAfterSync() {
    os_log("Start background manager after sync", log: self.log, type: .info)
    intentManager.registerXCallbackURLs()
    playableDownloadManager.start()
    artworkDownloadManager.start()
    backgroundLibrarySyncer.start()
    #if targetEnvironment(macCatalyst)
      player.addNotifier(notifier: self)
    #endif
  }

  func startManagerForNormalOperation() {
    os_log("Start background manager for normal operation", log: self.log, type: .info)
    intentManager.registerXCallbackURLs()
    duplicateEntitiesResolver.start()
    artworkDownloadManager.start()
    playableDownloadManager.start()
    backgroundLibrarySyncer.start()
    scrobbleSyncer?.start()
    #if targetEnvironment(macCatalyst)
      player.addNotifier(notifier: self)
    #endif
  }

  func setAppTheme(color: UIColor) {
    UIView.appearance().tintColor = color
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
    backgroundLibrarySyncer.stop()
    storage.main.saveContext()
  }

  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @Sendable @escaping () -> ()
  ) {
    os_log("handleEventsForBackgroundURLSession: %s", log: self.log, type: .info, identifier)
    playableDownloadManager.setBackgroundFetchCompletionHandler(completionHandler)
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

    #if targetEnvironment(macCatalyst)
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
    #endif

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
    if intent is SearchAndPlayIntent {
      return SearchAndPlayIntentHandler(intentManager: intentManager)
    }
    if intent is PlayIDIntent {
      return PlayIDIntentHandler(intentManager: intentManager)
    }
    if intent is INPlayMediaIntent {
      return PlayMediaIntentHandler(intentManager: intentManager)
    }
    if intent is PlayRandomSongsIntent {
      return PlayRandomSongsIntentHandler(intentManager: intentManager)
    }
    return nil
  }

  func createSleepTimerMenu(refreshCB: VoidFunctionCallback?) -> UIMenuElement {
    if let timer = sleepTimer {
      #if targetEnvironment(macCatalyst)
        let actionTitle = "Turn Off (Pause at: \(timer.fireDate.asShortHrMinString))"
      #else
        let actionTitle = "Turn Off"
      #endif
      let deactivate = UIAction(title: actionTitle, image: nil, handler: { _ in
        self.sleepTimer?.invalidate()
        self.sleepTimer = nil
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        subtitle: "Pause at: \(timer.fireDate.asShortHrMinString)",
        children: [deactivate]
      )
    } else if player.isShouldPauseAfterFinishedPlaying {
      #if targetEnvironment(macCatalyst)
        let actionTitle = "Turn Off (Pause at end of \(player.playerMode.playableName))"
      #else
        let actionTitle = "Turn Off"
      #endif
      let deactivate = UIAction(title: actionTitle, image: nil, handler: { _ in
        self.player.isShouldPauseAfterFinishedPlaying = false
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        subtitle: "Pause at end of \(player.playerMode.playableName)",
        children: [deactivate]
      )
    } else {
      let endOfTrack = UIAction(title: "End of Song or Podcast Episode", image: nil, handler: { _ in
        self.player.isShouldPauseAfterFinishedPlaying = true
        refreshCB?()
      })
      let sleep5 = UIAction(title: "5 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(5 * 60))
        refreshCB?()
      })
      let sleep10 = UIAction(title: "10 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(10 * 60))
        refreshCB?()
      })
      let sleep15 = UIAction(title: "15 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(15 * 60))
        refreshCB?()
      })
      let sleep30 = UIAction(title: "30 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(30 * 60))
        refreshCB?()
      })
      let sleep45 = UIAction(title: "45 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(45 * 60))
        refreshCB?()
      })
      let sleep60 = UIAction(title: "1 Hour", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(60 * 60))
        refreshCB?()
      })
      let sleep120 = UIAction(title: "2 Hours", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(2 * 60 * 60))
        refreshCB?()
      })
      let sleep240 = UIAction(title: "4 Hours", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(4 * 60 * 60))
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        children: [
          endOfTrack,
          sleep5,
          sleep10,
          sleep15,
          sleep30,
          sleep45,
          sleep60,
          sleep120,
          sleep240,
        ]
      )
    }
  }

  private func activateSleepTimer(timeInterval: TimeInterval) {
    appDelegate.sleepTimer?.invalidate()
    appDelegate.sleepTimer = Timer
      .scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
        Task { @MainActor in
          self.appDelegate.player.pause()
          self.appDelegate.eventLogger.info(
            topic: "Sleep Timer",
            message: "Sleep Timer paused playback."
          )
          self.appDelegate.sleepTimer?.invalidate()
          self.appDelegate.sleepTimer = nil
        }
      }
  }

  #if targetEnvironment(macCatalyst)
    var isMainOrMiniPlayerPlayerOpen: Bool {
      isMainWindowOpen || isShowingMiniPlayer
    }

    var isMainWindowOpen: Bool {
      !UIApplication.shared.connectedScenes
        .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
        .filter { ($0.rootViewController as? SplitVC) != nil }
        .isEmpty
    }

    func closeMainWindow() {
      // Close all main sessions (this might be more than one with multiple tabs open)
      UIApplication.shared.connectedScenes
        .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
        .filter { ($0.rootViewController as? SplitVC) != nil }
        .compactMap { $0.windowScene?.session }
        .forEach {
          let options = UIWindowSceneDestructionRequestOptions()
          options.windowDismissalAnimation = .standard
          UIApplication.shared.requestSceneSessionDestruction(
            $0,
            options: options,
            errorHandler: nil
          )
        }
    }

    func openMainWindow() {
      let defaultActivity = NSUserActivity(activityType: defaultWindowActivityType)
      UIApplication.shared.requestSceneSessionActivation(
        nil,
        userActivity: defaultActivity,
        options: nil,
        errorHandler: nil
      )
    }

    public func rebuildMainMenu() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
      super.buildMenu(with: builder)

      guard builder.system == .main else { return }

      // Add File menu
      let fileMenu = UIMenu(title: "File", children: [
        UIMenu(options: .displayInline, children: [
          UIAction(
            title: "Open Player Window",
            attributes: isMainOrMiniPlayerPlayerOpen ? .disabled : []
          ) { _ in
            self.openMainWindow()
          },
          UIKeyCommand(
            title: "Close Player Window",
            action: #selector(closePlayerWindow),
            input: "W",
            modifierFlags: .command,
            attributes: !isMainOrMiniPlayerPlayerOpen ? .disabled : []
          ),
        ]),
        UIMenu(options: .displayInline, children: [
          UIAction(title: "Switch Library/Mini Player") { _ in
            if self.isShowingMiniPlayer {
              self.closeMiniPlayer()
              self.openMainWindow()
            } else {
              self.closeMainWindow()
              self.showMiniPlayer()
            }
          },
        ]),
      ])
      builder.insertSibling(fileMenu, beforeMenu: .edit)
      let openSettingsMenu = UIMenu(options: .displayInline, children: [
        UIKeyCommand(
          title: "Settings…",
          action: #selector(showSettings),
          input: ",",
          modifierFlags: .command
        ),
      ])
      builder.insertSibling(openSettingsMenu, afterMenu: .about)

      // Add media controls
      builder.insertSibling(buildControlsMenu(), afterMenu: .view)

      // Add Help menu
      let helpMenu = UIMenu(title: "Help", children: [
        UIMenu(options: .displayInline, children: [
          UIAction(title: "Report an issue on GitHub") { _ in
            if let url = URL(string: "https://github.com/BLeeEZ/amperfy/issues") {
              UIApplication.shared.open(url)
            }
          },
        ]),
      ])
      builder.insertSibling(helpMenu, afterMenu: .window)

      // Remove not needed default menu items
      builder.remove(menu: .toolbar)
      builder.remove(menu: .file)
      builder.remove(menu: .format)
      builder.remove(menu: .font)
      builder.remove(menu: .text)
      builder.remove(menu: .services)
      builder.remove(menu: .help)

      if (focusedWindowTitle == windowSettingsTitle) ||
        (focusedWindowTitle == windowMiniPlayerTitle) {
        // Do any settings specific menu setup here
        builder.remove(menu: .view)
      } else {
        builder.remove(menu: .sidebar)
      }
    }

    @objc
    private func keyCommandPause() {
      player.pause()
    }

    @objc
    private func keyCommandPlay() {
      player.play()
    }

    @objc
    private func keyCommandStop() {
      player.stop()
    }

    @objc
    private func keyCommandNext() {
      player.playNext()
    }

    @objc
    private func keyCommandPrevious() {
      player.playPreviousOrReplay()
    }

    @objc
    private func keyCommandSkipForward() {
      player.skipForward(interval: player.skipForwardInterval)
    }

    @objc
    private func keyCommandSkipBackward() {
      player.skipBackward(interval: player.skipBackwardInterval)
    }

    @objc
    private func keyCommandGoToCurrent() {
      let playable = player.currentlyPlaying
      guard let album = playable?.asSong?.album else { return }
      appDelegate.userStatistics.usedAction(.alertGoToAlbum)
      let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
      albumDetailVC.album = album
      albumDetailVC.songToScrollTo = playable?.asSong
      displayInLibraryTab(vc: albumDetailVC)
    }

    @objc
    private func keyCommandShuffleOn() {
      guard !player.isShuffle else { return }
      player.toggleShuffle()
    }

    @objc
    private func keyCommandShuffleOff() {
      guard player.isShuffle else { return }
      player.toggleShuffle()
    }

    private func buildControlsMenu() -> UIMenu {
      let isPlaying = player.isPlaying
      let isShuffle = player.isShuffle
      let isSkipAvailable = isPlaying && player.isSkipAvailable
      let hasAlbum = player.currentlyPlaying?.asSong?.album != nil

      let section1 = [
        UIKeyCommand(
          title: isPlaying ? (player.isStopInsteadOfPause ? "Stop Radio" : "Pause") : "Play",
          action: isPlaying ? #selector(keyCommandPause) : #selector(keyCommandPlay),
          input: " "
        ),
        UIKeyCommand(
          title: (isPlaying && player.isStopInsteadOfPause) ? "Stop Player" : "Stop",
          action: #selector(keyCommandStop),
          input: ".",
          modifierFlags: .command,
          attributes: isPlaying ? [] : [.disabled]
        ),
        UIKeyCommand(
          title: "Next Track",
          action: #selector(keyCommandNext),
          input: UIKeyCommand.inputRightArrow,
          modifierFlags: .command,
          attributes: isPlaying ? [] : [.disabled]
        ),
        UIKeyCommand(
          title: "Previous Track",
          action: #selector(keyCommandPrevious),
          input: UIKeyCommand.inputLeftArrow,
          modifierFlags: .command,
          attributes: isPlaying ? [] : [.disabled]
        ),
        UIKeyCommand(
          title: "Skip Forward: " + Int(player.skipForwardInterval).description + " sec.",
          action: #selector(keyCommandSkipForward),
          input: UIKeyCommand.inputRightArrow,
          modifierFlags: [.shift, .command],
          attributes: isSkipAvailable ? [] : [.disabled]
        ),
        UIKeyCommand(
          title: "Skip Backward: " + Int(player.skipBackwardInterval).description + " sec.",
          action: #selector(keyCommandSkipBackward),
          input: UIKeyCommand.inputLeftArrow,
          modifierFlags: [.shift, .command],
          attributes: isSkipAvailable ? [] : [.disabled]
        ),
        UIKeyCommand(
          title: "Go to Current Song",
          action: #selector(keyCommandGoToCurrent),
          input: "L",
          modifierFlags: [.command],
          attributes: hasAlbum ? [] : [.disabled]
        ),
      ]

      var section2 = [
        UIMenu(title: "Playback Rate", children: PlaybackRate.allCases.map { rate in
          UIAction(
            title: rate.description,
            state: rate == self.player.playbackRate ? .on : .off
          ) { _ in
            self.player.setPlaybackRate(rate)
          }
        }),
      ]

      if appDelegate.player.playerMode == .music {
        let repeatMenu = UIMenu(title: "Repeat", children: RepeatMode.allCases.map { mode in
          UIAction(
            title: mode.description,
            state: mode == self.player.repeatMode ? .on : .off
          ) { _ in
            self.player.setRepeatMode(mode)
          }
        })
        section2.insert(repeatMenu, at: 0)
      }
      if appDelegate.player.playerMode == .music,
         appDelegate.storage.settings.isPlayerShuffleButtonEnabled {
        let shuffleMenu = UIMenu(title: "Shuffle", children: [
          UIAction(title: "On", state: isShuffle ? .on : .off) { [weak self] _ in
            self?.keyCommandShuffleOn()
          },
          UIAction(title: "Off", state: !isShuffle ? .on : .off) { [weak self] _ in
            self?.keyCommandShuffleOff()
          },
        ])
        section2.insert(shuffleMenu, at: 0)
      }

      let section3 = [
        createSleepTimerMenu(refreshCB: {
          UIMenuSystem.main.setNeedsRebuild()
        }),
      ]

      let section4 = [
        UIAction(title: "Switch Music/Podcast mode") { _ in
          self.player.setPlayerMode(self.player.playerMode.nextMode)
        },
      ]

      let sections: [[UIMenuElement]] = [section1, section2, section3, section4]

      return UIMenu(title: "Controls", children: sections.reduce([]) { result, section in
        result + [UIMenu(options: .displayInline)] + section
      })
    }

    @objc
    func closePlayerWindow(sender: Any) {
      if isMainWindowOpen {
        closeMainWindow()
      } else if isShowingMiniPlayer {
        closeMiniPlayer()
      }
    }

    @objc
    func showSettings(sender: Any) {
      let settingsActivity = NSUserActivity(activityType: settingsWindowActivityType)
      UIApplication.shared.requestSceneSessionActivation(
        settingsSceneSession,
        userActivity: settingsActivity,
        options: nil,
        errorHandler: nil
      )
    }

    var isShowingMiniPlayer: Bool {
      UIApplication.shared.connectedScenes.contains(where: { $0.session == miniPlayerSceneSession })
    }

    @objc
    func showMiniPlayer(sender: Any? = nil) {
      let miniPlayerActivity = NSUserActivity(activityType: miniPlayerWindowActivityType)
      UIApplication.shared.requestSceneSessionActivation(
        miniPlayerSceneSession,
        userActivity: miniPlayerActivity,
        options: nil,
        errorHandler: nil
      )
    }

    func closeMiniPlayer() {
      UIApplication.shared.connectedScenes
        .filter { $0.session == miniPlayerSceneSession }
        .forEach {
          let options = UIWindowSceneDestructionRequestOptions()
          options.windowDismissalAnimation = .standard
          UIApplication.shared.requestSceneSessionDestruction(
            $0.session,
            options: options,
            errorHandler: nil
          )
        }
    }
  #endif
}

#if targetEnvironment(macCatalyst)
  extension AppDelegate: MusicPlayable {
    func didStartPlaying() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didPause() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didStopPlaying() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didShuffleChange() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didRepeatChange() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didPlaybackRateChange() {
      UIMenuSystem.main.setNeedsRebuild()
    }

    func didStartPlayingFromBeginning() {}
    func didElapsedTimeChange() {}
    func didPlaylistChange() {}
    func didArtworkChange() {}
  }
#endif
