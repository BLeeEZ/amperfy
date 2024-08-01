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

import UIKit
import AmperfyKit

class SplitVC: UISplitViewController {

    lazy var barPlayer = BarPlayerHandler(player: appDelegate.player, splitVC: self)
    
    var isCompact: Bool {
        return (traitCollection.horizontalSizeClass == .compact)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setViewController(defaultSecondaryVC, for: .secondary)
        
        if appDelegate.storage.settings.isOfflineMode {
            appDelegate.eventLogger.info(topic: "Reminder", message: "Offline Mode is active.")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        self.updateScene(title: self.viewControllers.last?.sceneTitle)
        
        super.viewDidAppear(animated)
        setCorrectPlayerBarView(collapseMode: isCompact)
        if !appDelegate.storage.isLibrarySyncInfoReadByUser {
            displaySyncInfo()
        } else {
            displayNotificationAuthorization()
        }
    }
    
    func embeddInNavigation(vc: UIViewController) -> UINavigationController {
        return UINavigationController(rootViewController: vc)
    }
    
    var defaultSecondaryVC: UINavigationController {
        return embeddInNavigation(vc: TabNavigatorItem.search.controller)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass else { return }
        if isCompact {
            setCorrectPlayerBarView(collapseMode: true)
            guard let secondaryVC = viewController(for: .secondary),
                  let compactVC = viewController(for: .compact)
            else { return }
            collapseSecondary(secondaryViewController: secondaryVC, onto: compactVC)
        } else {
            setCorrectPlayerBarView(collapseMode: false)
            guard let compactVC = viewController(for: .compact) else { return }
            let vc = separateSecondary(from: compactVC)
            setViewController(vc, for: .secondary)
            self.updateScene(title: vc?.sceneTitle)
        }
    }
    
    private func collapseSecondary(secondaryViewController: UIViewController, onto primaryViewController: UIViewController) {
        if let navBar = secondaryViewController as? UINavigationController,
           let rootVC = navBar.viewControllers.first,
           let tabBar = self.viewController(for: .compact) as? TabBarVC,
           let hostingTabViewControllers = tabBar.viewControllers,
           hostingTabViewControllers.count >= 2 {
            if rootVC is SettingsHostVC {
                tabBar.viewControllers?[2].loadViewIfNeeded()
                navBar.viewControllers = [UIViewController]()
                secondaryViewController.view.layoutIfNeeded()
                var curTabVC = hostingTabViewControllers
                curTabVC.insert(rootVC, at: 2)
                curTabVC.remove(at: 3)
                tabBar.setViewControllers(curTabVC, animated: false)
                tabBar.selectedIndex = 2
            } else if rootVC is SearchVC {
                tabBar.viewControllers?[1].loadViewIfNeeded()
                if let nav = tabBar.viewControllers?[1] as? UINavigationController {
                    let navBarVCs = navBar.viewControllers
                    navBar.viewControllers = [UIViewController]()
                    secondaryViewController.view.layoutIfNeeded()
                    nav.setViewControllers(navBarVCs, animated: false)
                    tabBar.selectedIndex = 1
                }
            } else {
                tabBar.viewControllers?[0].loadViewIfNeeded()
                if let nav = tabBar.viewControllers?[0] as? UINavigationController {
                    var navBarVCs = navBar.viewControllers
                    navBar.viewControllers = [UIViewController]()
                    secondaryViewController.view.layoutIfNeeded()
                    navBarVCs.insert(LibraryVC.instantiateFromAppStoryboard(), at: 0)
                    nav.setViewControllers(navBarVCs, animated: false)
                    tabBar.selectedIndex = 0
                }
            }
        }
    }

    private func separateSecondary(from primaryViewController: UIViewController) -> UIViewController? {
        guard let tabBar = primaryViewController as? TabBarVC,
              let tabVCs = tabBar.viewControllers,
              tabVCs.count >= 2
        else { return nil }
        if tabBar.selectedIndex == 0,
           let navBar = tabVCs[0] as? UINavigationController {
            if navBar.viewControllers.count > 1 {
                let vcs = Array(navBar.viewControllers.dropFirst())
                navBar.viewControllers = [LibraryVC.instantiateFromAppStoryboard()]
                primaryViewController.view.layoutIfNeeded()
                let secondaryVC = UINavigationController(rootViewController: UIViewController())
                secondaryVC.setViewControllers(vcs, animated: false)
                return secondaryVC
            } else {
                return defaultSecondaryVC
            }
        } else if tabBar.selectedIndex == 1,
                  let navBar = tabVCs[1] as? UINavigationController {
            let vcs = navBar.viewControllers
            navBar.viewControllers = [TabNavigatorItem.search.controller]
            primaryViewController.view.layoutIfNeeded()
            let secondaryVC = UINavigationController(rootViewController: UIViewController())
            secondaryVC.setViewControllers(vcs, animated: false)
            return secondaryVC
        } else if tabBar.selectedIndex == 2,
                  let settingsVC = tabVCs[2] as? SettingsHostVC {
            let nav = UINavigationController(rootViewController: settingsVC)
            var curTabVC = tabVCs
            curTabVC.insert(TabNavigatorItem.settings.controller, at: 2)
            curTabVC.remove(at: 3)
            tabBar.setViewControllers(curTabVC, animated: false)
            primaryViewController.view.layoutIfNeeded()
            return nav
        } else {
            return nil
        }
    }
    
    private func displaySyncInfo() {
        let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
        popupVC.setContent(
            topic: "Synchronization",
            detailMessage: "Your music collection is constantly updating. Already synced library items are offline available. If library items (artists/albums/songs) are not shown in your  collection please use the various search functionalities to synchronize with the server.",
            customIcon: .refresh,
            customAnimation: .rotate,
            onClosePressed: { _ in
                self.appDelegate.storage.isLibrarySyncInfoReadByUser = true
                self.displayNotificationAuthorization()
            }
        )
        appDelegate.display(popup: popupVC)
    }
    
    private func displayNotificationAuthorization() {
        self.appDelegate.localNotificationManager.executeIfAuthorizationHasNotBeenAskedYet {
            DispatchQueue.main.async {
                let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
                popupVC.setContent(
                    topic: "Notifications",
                    detailMessage: "Amperfy can inform you about the latest podcast episodes. If you want to, please authorize Amperfy to send you notifications.",
                    customIcon: .bell,
                    customAnimation: .swing,
                    onClosePressed: { _ in
                        self.appDelegate.localNotificationManager.requestAuthorization()
                    }
                )
                self.appDelegate.display(popup: popupVC)
            }
        }
    }
    
    private func setCorrectPlayerBarView(collapseMode: Bool) {
        #if targetEnvironment(macCatalyst)
        // always show the player in the sidebar on macOS
        barPlayer.changeTo(vc: self.viewControllers.first!)
        #else
        if collapseMode {
            let vc = self.viewController(for: .compact)
            guard let vc = vc else { return }
            barPlayer.changeTo(vc: vc)
        } else {
            barPlayer.changeTo(vc: self)
        }
        #endif
    }
    
    private var popupBarContainerVC: UIViewController? {
        if isCompact {
            if  let tabBar = self.viewController(for: .compact) as? TabBarVC {
                return tabBar
            }
        } else {
            return self
        }
        return nil
    }
    
    public func pushNavLibrary(vc: UIViewController) {
        if isCompact,
           let tabBar = self.viewController(for: .compact) as? TabBarVC {
           if tabBar.popupPresentationState == .open,
              let popupPlayerVC = tabBar.popupContent as? PopupPlayerVC {
               popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: vc)
           } else {
               push(vc: vc)
           }
        } else if !isCompact {
            push(vc: vc)
        }
    }
    
    func updateScene(title: String?) {
        self.view.window?.windowScene?.title = title ?? Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
    }

    public func pushReplaceNavLibrary(vc: UIViewController) {
        if isCompact {
           if let tabBar = self.viewController(for: .compact) as? TabBarVC,
              let hostingTabViewControllers = tabBar.viewControllers,
              hostingTabViewControllers.count > 0,
              let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
               tabBar.selectedIndex = 0
               libraryTabNavVC.pushViewController(vc, animated: true)
           }
        } else {
            setViewController(embeddInNavigation(vc: vc), for: .secondary)
        }
        updateScene(title: vc.sceneTitle)
    }
    
    public func push(vc: UIViewController) {
        if isCompact {
            if let tabBar = self.viewController(for: .compact) as? TabBarVC,
               let hostingTabViewControllers = tabBar.viewControllers,
               hostingTabViewControllers.count > 0,
               let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
                libraryTabNavVC.pushViewController(vc, animated: false)
                tabBar.selectedIndex = 0
            }
        } else {
            if let secondaryVC = self.viewController(for: .secondary) as? UINavigationController {
                secondaryVC.pushViewController(vc, animated: false)
            }
        }
        updateScene(title: vc.sceneTitle)
    }
    
    public func visualizePopupPlayer(direction: PopupPlayerDirection, animated: Bool, completion completionBlock: (()->Void)? = nil) {
        guard let topView = AppDelegate.topViewController(),
              let popupBarContainerVC = popupBarContainerVC
        else { return }
        
        if let presentedViewController = topView.presentedViewController {
            presentedViewController.dismiss(animated: animated) {
                togglePopupPlayer()
            }
        } else {
            togglePopupPlayer()
        }
        
        func togglePopupPlayer() {
            if popupBarContainerVC.popupPresentationState == .open,
               let _ = popupBarContainerVC.popupContent as? PopupPlayerVC,
               direction != .open {
                popupBarContainerVC.closePopup(animated: animated) {
                    completionBlock?()
                }
            } else if popupBarContainerVC.popupPresentationState == .barPresented,
                      direction != .close {
                popupBarContainerVC.openPopup(animated: true) {
                    completionBlock?()
                }
            } else {
                completionBlock?()
            }
        }
    }
    
    func displaySearch() {
        visualizePopupPlayer(direction: .close, animated: true) {
            if self.isCompact {
                if let tabBar = self.viewController(for: .compact) as? TabBarVC,
                   let hostingTabViewControllers = tabBar.viewControllers,
                   hostingTabViewControllers.count >= 2,
                   let searchTabNavVC = hostingTabViewControllers[1] as? UINavigationController {
                    tabBar.selectedIndex = 1
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        if let searchTabVC = searchTabNavVC.visibleViewController as? SearchVC {
                            searchTabVC.activateSearchBar()
                        }
                    }
                }
            } else {
                let searchVC = TabNavigatorItem.search.controller
                self.setViewController(UINavigationController(rootViewController: searchVC), for: .secondary)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    if let activeSearchVC = searchVC as? SearchVC {
                        activeSearchVC.activateSearchBar()
                    }
                }
            }
        }
    }
    
}


extension UIViewController {
    @objc var sceneTitle: String? { nil }
}

extension UINavigationController {
    override var sceneTitle: String? { self.topViewController?.sceneTitle }
}
