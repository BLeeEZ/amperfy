//
//  AppDelegateAlertExtensions.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 13.10.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import Foundation
import OSLog
import UIKit

extension AppDelegate {
  static var mainSceneDelegate: SceneDelegate? {
    UIApplication.shared.connectedScenes
      // only scenes that are attached
      .filter { $0.activationState.rawValue >= 0 }
      // sort order: foregroundActive < foregroundInactive < background
      // this places the active tab first
      .sorted { $0.activationState.rawValue < $1.activationState.rawValue }
      // only "main" scene delegates
      .compactMap { $0.delegate as? SceneDelegate }.first
  }

  public func closeAllButActiveMainTabs() {
    var allMainScenes = UIApplication.shared.connectedScenes
      // only scenes that are attached
      .filter { $0.activationState.rawValue >= 0 }
      // sort order: foregroundActive < foregroundInactive < background
      // this places the active tab first
      .sorted { $0.activationState.rawValue < $1.activationState.rawValue }
      // only "main" scene delegates
      .filter { $0.delegate is SceneDelegate }
    if !allMainScenes.isEmpty {
      allMainScenes.removeFirst()
    }
    for scene in allMainScenes {
      terminateScene(scene)
    }
  }

  private func terminateScene(_ scene: UIScene) {
    UIApplication.shared.requestSceneSessionDestruction(
      scene.session,
      options: nil,
      errorHandler: { error in
        os_log(
          "AppDelegate: terminateScene failed: %s",
          log: self.log,
          type: .info,
          error.localizedDescription
        )
      }
    )
  }

  static var window: UIWindow? {
    mainSceneDelegate?.window
  }

  static func rootViewController() -> UIViewController? {
    Self.window?.rootViewController
  }

  static func topViewController(
    base: UIViewController? =
      window?.rootViewController
  )
    -> UIViewController? {
    if base?.presentedViewController is UIAlertController {
      return base
    }
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? TabBarVC {
      return tab
    }
    if let splitVC = base as? SplitVC {
      return splitVC
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }

  static var mainWindowHostVC: MainSceneHostingViewController? {
    guard let topView = Self.topViewController(),
          (UIApplication.shared.delegate as! AppDelegate).storage.settings.app.isLibrarySynced
    else { return nil }
    return AppStoryboard.Main.checkForMainWindow(vc: topView)
  }
}

// MARK: - AppDelegate + AlertDisplayable

extension AppDelegate: AlertDisplayable {
  func display(
    title: String,
    subtitle: String,
    style: LogEntryType,
    notificationBanner popupVC: UIViewController
  ) {
    guard !Toast.isVisible,
          let topView = Self.topViewController(),
          topView.presentedViewController == nil,
          // no key window: the app is in the background
          UIApplication.shared.mainWindow != nil,
          let window = Self.window
    else { return }

    Toast.show(
      title: title,
      subtitle: subtitle,
      style: style,
      in: window,
      placement: Self.toastPlacement(in: window, host: topView)
    ) {
      guard let topView = Self.topViewController(),
            topView.presentedViewController == nil
      else { return }
      topView.present(popupVC, animated: true, completion: nil)
    }
  }

  /// The toast floats above the mini player and is centered on it. In a split view the mini
  /// player keeps its slot while no title is loaded, so the toast stays where it will be later.
  /// Without a mini player slot it sits above the tab bar or the bottom safe area.
  private static func toastPlacement(
    in window: UIWindow,
    host: UIViewController
  )
    -> ToastPlacement {
    // frames in the upper half belong to a top tab bar (iPad), not to a bottom bar
    func bottomFrame(of view: UIView, requiresVisible: Bool = true) -> CGRect? {
      guard view.window === window else { return nil }
      if requiresVisible, view.isHidden || view.alpha <= 0.01 { return nil }
      let frame = view.convert(view.bounds, to: window)
      return !frame.isEmpty && frame.minY > window.bounds.midY ? frame : nil
    }

    let slotFrame: CGRect?
    if let splitVC = host as? SplitVC {
      slotFrame = splitVC.miniPlayer.flatMap {
        bottomFrame(of: $0.glassContainer, requiresVisible: false)
      }
    } else {
      slotFrame = (host as? TabBarVC)?.miniPlayer.flatMap {
        bottomFrame(of: $0.glassContainer)
      }
    }
    let tabBarFrame = (host as? TabBarVC).flatMap { bottomFrame(of: $0.tabBar) }

    return ToastPlacement(
      centerX: slotFrame?.midX ?? window.bounds.midX,
      bottomEdge: (slotFrame ?? tabBarFrame)?.minY
        ?? window.bounds.maxY - window.safeAreaInsets.bottom
    )
  }

  func display(popup popupVC: UIViewController) {
    guard let topView = Self.topViewController(),
          topView.presentedViewController == nil
    else { return }
    popupVC.modalPresentationStyle = .overCurrentContext
    popupVC.modalTransitionStyle = .crossDissolve
    topView.present(popupVC, animated: true, completion: nil)
  }

  func createPopupVC(
    topic: String,
    shortMessage: String,
    detailMessage: String,
    logType: LogEntryType
  )
    -> UIViewController {
    let detailVC = NotificationDetailVC()
    detailVC.display(title: topic, message: detailMessage, type: logType)
    // the navigation bar shows the title and the system close button
    return UINavigationController(rootViewController: detailVC)
  }
}
