//
//  SplitVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import SwiftUI

// MARK: - SplitVC

class SplitVC: UISplitViewController {
  public static let sidebarWidth: CGFloat = 250
  public static let inspectorWidth: CGFloat = 300

  var miniPlayer: MiniPlayerView?
  var miniPlayerLeadingConstraint: NSLayoutConstraint?
  var miniPlayerTrailingConstraint: NSLayoutConstraint?
  var miniPlayerBottomConstraint: NSLayoutConstraint?
  var miniPlayerHeightConstraint: NSLayoutConstraint?
  var welcomePopupPresenter = WelcomePopupPresenter()
  private let account: Account!

  init(style: UISplitViewController.Style, account: Account) {
    self.account = account
    super.init(style: style)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setViewController(
      embeddInNavigation(vc: AppStoryboard.Main.segueToSideBar(account: account)),
      for: .primary
    )
    setViewController(defaultSecondaryVC, for: .secondary)
    primaryEdge = .leading
    primaryBackgroundStyle = .sidebar

    if appDelegate.storage.settings.user.isOfflineMode {
      appDelegate.eventLogger.info(topic: "Reminder", message: "Offline Mode is active.")
    }

    miniPlayer = MiniPlayerView(player: appDelegate.player)
    miniPlayer!.configureForMac()
    guard let miniPlayer else { return }

    let inspectorWidth = viewController(for: .inspector)?.view.bounds.width ?? 0.0
    displayOrHideInspector()

    view.addSubview(miniPlayer.glassContainer)
    // Set up constraints to pin it to the bottom, left, and right
    miniPlayer.glassContainer.translatesAutoresizingMaskIntoConstraints = false

    miniPlayer.glassContainer.layer.cornerRadius = 25
    miniPlayer.glassContainer.clipsToBounds = true

    miniPlayerLeadingConstraint = miniPlayer.glassContainer.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: primaryColumnWidth + 20
    )
    miniPlayerTrailingConstraint = miniPlayer.glassContainer.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -inspectorWidth - 20
    )
    miniPlayerBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(
      equalTo: miniPlayer.glassContainer.bottomAnchor,
      constant: 15.0
    )
    miniPlayerHeightConstraint = miniPlayer.glassContainer.heightAnchor
      .constraint(equalToConstant: 50)

    NSLayoutConstraint.activate([
      miniPlayerLeadingConstraint!,
      miniPlayerTrailingConstraint!,
      miniPlayerBottomConstraint!,
      miniPlayerHeightConstraint!,
    ])
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()

    let inspectorWidth = viewController(for: .inspector)?.view.bounds.width ?? 0.0

    miniPlayerLeadingConstraint?.constant = (isSidebarVisible ? primaryColumnWidth : -0) + 40
    miniPlayerTrailingConstraint?.constant = -inspectorWidth - 40
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)

    // set min and max sidebar width
    minimumPrimaryColumnWidth = Self.sidebarWidth
    maximumPrimaryColumnWidth = Self.sidebarWidth
    minimumInspectorColumnWidth = Self.sidebarWidth
    maximumInspectorColumnWidth = Self.sidebarWidth
    welcomePopupPresenter.displayInfoPopupsIfNeeded()
    miniPlayer?.refreshPlayer()
  }

  func displayOrHideInspector() {
    if appDelegate.storage.settings.user.isPlayerLyricsDisplayed {
      let lyricsVC = LyricsVC()
      setViewController(lyricsVC, for: .inspector)
      show(.inspector)
    } else if appDelegate.storage.settings.user.playerDisplayStyle == .compact {
      let queueVC = QueueVC()
      setViewController(queueVC, for: .inspector)
      show(.inspector)
    } else {
      hide(.inspector)
      setViewController(nil, for: .inspector)
    }
  }

  var isSidebarVisible: Bool {
    switch displayMode {
    case .allVisible, .automatic, .oneBesideSecondary, .primaryOverlay, .twoBesideSecondary,
         .twoDisplaceSecondary:
      // Sidebar is visible in some capacity
      return true
    case .oneOverSecondary, .secondaryOnly, .twoOverSecondary:
      // Sidebar is occupying main space
      return false
    @unknown default:
      return true
    }
  }

  func embeddInNavigation(vc: UIViewController) -> UINavigationController {
    UINavigationController(rootViewController: vc)
  }

  var defaultSecondaryVC: UINavigationController {
    embeddInNavigation(vc: TabNavigatorItem.home.getController(account: account))
  }

  public func push(vc: UIViewController) {
    let secondaryVC = viewController(for: .secondary) as? UINavigationController
    secondaryVC?.pushViewController(vc, animated: false)
  }
}

// MARK: MainSceneHostingViewController

extension SplitVC: MainSceneHostingViewController {
  public func pushNavLibrary(vc: UIViewController) {
    push(vc: vc)
  }

  public func pushLibraryCategory(vc: UIViewController) {
    setViewController(embeddInNavigation(vc: vc), for: .secondary)
  }

  func pushTabCategory(tabCategory: TabNavigatorItem) {
    let vc = tabCategory.getController(account: account)
    setViewController(embeddInNavigation(vc: vc), for: .secondary)
  }

  func displaySearch() {
    visualizePopupPlayer(direction: .close, animated: true) {
      let searchVC = AppStoryboard.Main.segueToSearch(account: self.account)
      self.setViewController(self.embeddInNavigation(vc: searchVC), for: .secondary)
      Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        searchVC.activateSearchBar()
      }
    }
  }

  func getSafeAreaExtension() -> CGFloat {
    guard let miniPlayerBottomConstraint,
          let miniPlayerHeightConstraint else { return 0.0 }

    return miniPlayerBottomConstraint.constant + miniPlayerHeightConstraint.constant
  }
}
