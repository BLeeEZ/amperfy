//
//  TabBarVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import UIKit

// MARK: - TabBarVC

class TabBarVC: UITabBarController {
  private var libraryGroup: UITabGroup?
  private var searchTab: UISearchTab?
  private var homeTab: UITab?
  private let account: Account

  init(account: Account) {
    self.account = account
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var welcomePopupPresenter = WelcomePopupPresenter()
  var miniPlayer: MiniPlayerView?

  override func viewDidLoad() {
    super.viewDidLoad()
    var fixTabs = [UITab]()

    searchTab = UISearchTab { _ in
      UINavigationController(
        rootViewController: TabNavigatorItem.search
          .getController(account: self.account)
      )
    }
    searchTab!.automaticallyActivatesSearch = true
    fixTabs.append(searchTab!)

    homeTab = UITab(
      title: TabNavigatorItem.home.title,
      image: TabNavigatorItem.home.icon,
      identifier: "Tabs.\(TabNavigatorItem.home.title)"
    ) { _ in
      UINavigationController(
        rootViewController: TabNavigatorItem.home
          .getController(account: self.account)
      )
    }
    fixTabs.append(homeTab!)

    var libraryTabs = [UITab]()
    let libraryTabsShown = appDelegate.storage.settings.accounts
      .getSetting(account.info).read
      .libraryDisplaySettings.inUse
      .compactMap { item in
        let tab = UITab(
          title: item.displayName,
          image: item.image,
          identifier: "Tabs.\(item.displayName)"
        ) { tab in
          item.controller(account: self.account, settings: self.appDelegate.storage.settings)
        }
        tab.allowsHiding = true
        return tab
      }
    libraryTabs.append(contentsOf: libraryTabsShown)

    let libraryTabsHidden = appDelegate.storage.settings.accounts
      .getSetting(account.info).read
      .libraryDisplaySettings.notUsed
      .compactMap { item in
        let tab = UITab(
          title: item.displayName,
          image: item.image,
          identifier: "Tabs.\(item.displayName)"
        ) { tab in
          item.controller(account: self.account, settings: self.appDelegate.storage.settings)
        }
        tab.allowsHiding = true
        tab.isHiddenByDefault = true
        return tab
      }
    libraryTabs.append(contentsOf: libraryTabsHidden)

    libraryGroup = UITabGroup(
      title: "Library",
      image: .musicLibrary,
      identifier: "Tabs.Library",
      children: libraryTabs
    ) { tab in
      AppStoryboard.Main.segueToLibrary(account: self.account)
    }
    libraryGroup!.managingNavigationController = UINavigationController()
    libraryGroup!.allowsReordering = true
    fixTabs.append(libraryGroup!)

    delegate = self
    tabs = fixTabs

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleLibraryItemsChanged(notification:)),
      name: .LibraryItemsChanged,
      object: nil
    )

    tabBarMinimizeBehavior = .onScrollDown

    miniPlayer = MiniPlayerView(player: appDelegate.player)
    miniPlayer!.configureForiOS()
    miniPlayer!.glassContainer.translatesAutoresizingMaskIntoConstraints = false

    let accessory = UITabAccessory(contentView: miniPlayer!.glassContainer)
    bottomAccessory = accessory

    heightConstraint = miniPlayer!.glassContainer.heightAnchor.constraint(equalToConstant: 48.0)
    heightConstraint?.isActive = true
    compactWidthConstraint = miniPlayer!.glassContainer.widthAnchor
      .constraint(equalTo: miniPlayer!.glassContainer.superview!.widthAnchor)

    miniPlayer!.tabAccessoryTraitChangeCB = configureTraitChangesForMiniPlayer
    configureTraitChangesForMiniPlayer()

    registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        self.miniPlayer?
          .refreshForTraitChange(horizontalSizeClass: self.traitCollection.horizontalSizeClass)
        self.configureTraitChangesForMiniPlayer()
      }
    )

    if appDelegate.storage.settings.user.isOfflineMode {
      appDelegate.eventLogger.info(topic: "Reminder", message: "Offline Mode is active.")
    }
  }

  private func mainContent() -> UIView {
    // Attempt to find the main content view controller's view if the sidebar is visible.
    // Fallback to self.view.safeAreaLayoutGuide.leadingAnchor otherwise.
    if traitCollection.horizontalSizeClass == .regular, let selectedViewController {
      return selectedViewController.view
    }
    return view
  }

  var centerConstraint: NSLayoutConstraint?
  var regularWidthConstraint: NSLayoutConstraint?
  var heightConstraint: NSLayoutConstraint?
  var compactWidthConstraint: NSLayoutConstraint?

  func configureTraitChangesForMiniPlayer() {
    guard let miniPlayer else { return }
    let isInline = miniPlayer.glassContainer.traitCollection.tabAccessoryEnvironment == .inline

    if traitCollection.horizontalSizeClass == .regular {
      centerConstraint = miniPlayer.glassContainer.safeAreaLayoutGuide.centerXAnchor.constraint(
        equalTo: mainContent().safeAreaLayoutGuide.centerXAnchor,
        constant: 0
      )
      let mainContentView = mainContent()
      var playerWidth = mainContentView.frame.width - mainContentView.safeAreaInsets
        .left - mainContentView.safeAreaInsets.right
      playerWidth = min(playerWidth, 600)
      compactWidthConstraint?.isActive = false
      regularWidthConstraint?.isActive = false
      regularWidthConstraint = miniPlayer.glassContainer.widthAnchor
        .constraint(equalToConstant: playerWidth)
      regularWidthConstraint?.isActive = true
      centerConstraint?.isActive = true
      heightConstraint?.constant = 60.0
    } else if isInline {
      heightConstraint?.constant = 48.0
      centerConstraint?.isActive = false
      regularWidthConstraint?.isActive = false
      compactWidthConstraint?.isActive = true
    } else {
      heightConstraint?.constant = 48.0
      centerConstraint?.isActive = false
      regularWidthConstraint?.isActive = false
      compactWidthConstraint?.isActive = true
    }

    miniPlayer.glassContainer.setNeedsLayout()
    miniPlayer.glassContainer.layoutIfNeeded()
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    configureTraitChangesForMiniPlayer()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    refresh()
    selectedTab = homeTab
    welcomePopupPresenter.displayInfoPopupsIfNeeded()
  }

  @objc
  func handleLibraryItemsChanged(notification: Notification) {
    refresh()
  }

  func refresh() {
    guard let libraryGroup else { return }
    let config = appDelegate.storage.settings.accounts.getSetting(account.info).read
      .libraryDisplaySettings
    libraryGroup.displayOrderIdentifiers = config.inUse.compactMap { "Tabs.\($0.displayName)" }
    for tab in libraryGroup.displayOrder {
      guard let item = LibraryDisplayType.createByDisplayName(name: tab.title) else { continue }
      if let _ = config.inUse.first(where: { $0 == item }) {
        tab.isHidden = false
      } else {
        tab.isHidden = true
      }
    }
  }

  public func push(vc: UIViewController) {
    guard let libraryGroup else { return }
    libraryGroup.managingNavigationController?.pushViewController(vc, animated: true)
    selectedTab = libraryGroup
  }
}

// MARK: UITabBarControllerDelegate

extension TabBarVC: UITabBarControllerDelegate {
  func tabBarControllerDidEndEditing(_ tabBarController: UITabBarController) {
    var visibleItems = [LibraryDisplayType]()
    guard let libraryGroup else { return }
    for tab in libraryGroup.displayOrder {
      guard let item = LibraryDisplayType.createByDisplayName(name: tab.title) else { continue }
      if !tab.isHidden {
        visibleItems.append(item)
      }
    }
    appDelegate.storage.settings.accounts
      .updateSetting(account.info) { accountSettings in
        accountSettings.libraryDisplaySettings = LibraryDisplaySettings(inUse: visibleItems)
      }
    NotificationCenter.default.post(name: .LibraryItemsChanged, object: nil, userInfo: nil)
  }
}

// MARK: MainSceneHostingViewController

extension TabBarVC: MainSceneHostingViewController {
  public func pushNavLibrary(vc: UIViewController) {
    push(vc: vc)
  }

  public func pushLibraryCategory(vc: UIViewController) {
    guard let libraryGroup else { return }
    libraryGroup.managingNavigationController?.popToRootViewController(animated: false)
    push(vc: vc)
  }

  func pushTabCategory(tabCategory: TabNavigatorItem) {
    switch tabCategory {
    case .home:
      selectedTab = homeTab
    case .search:
      selectedTab = searchTab
    }
    configureTraitChangesForMiniPlayer()
  }

  func displaySearch() {
    guard let searchTab else { return }
    visualizePopupPlayer(direction: .close, animated: true) {
      self.selectedTab = searchTab
      searchTab.viewController?.navigationController?.popToRootViewController(animated: false)
      Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        if let searchTabVC = searchTab.viewController?.navigationController?
          .topViewController as? SearchVC {
          searchTabVC.activateSearchBar()
        }
      }
    }
  }

  func getSafeAreaExtension() -> CGFloat {
    0.0
  }
}
