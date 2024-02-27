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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setViewController(UINavigationController(rootViewController: SideBarItems.search.controller), for: .secondary)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.isCollapsed {
            // if it is collapsed -> the delegate callback sets the player bar
            setCorrectPlayerBarView(collapseMode: false)
        }
        
        if !appDelegate.storage.isLibrarySyncInfoReadByUser {
            displaySyncInfo()
        } else {
            displayNotificationAuthorization()
        }
    }
    
    private func displaySyncInfo() {
        let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
        popupVC.setContent(
            topic: "Synchronization",
            shortMessage: nil,
            detailMessage: "Your music collection is constantly updating. Already synced library items are offline available. If library items (artists/albums/songs) are not shown in your  collection please use the various search functionalities to synchronize with the server.",
            clipboardContent: nil,
            type: .info,
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
                    shortMessage: nil,
                    detailMessage: "Amperfy can inform you about the latest podcast episodes. If you want to, please authorize Amperfy to send you notifications.",
                    clipboardContent: nil,
                    type: .info,
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
        if collapseMode {
            let vc = self.viewController(for: .compact)
            guard let vc = vc else { return }
            barPlayer.changeTo(vc: vc)
        } else {
            barPlayer.changeTo(vc: self)
        }
    }
    
    private var popupBarContainerVC: UIViewController? {
        if self.isCollapsed {
            if  let tabBar = self.viewController(for: .compact) as? TabBarVC {
                return tabBar
            }
        } else {
            return self
        }
        return nil
    }
    
    public func displayInLibraryTab(vc: UIViewController) {
        if self.isCollapsed,
           let tabBar = self.viewController(for: .compact) as? TabBarVC {
           if tabBar.popupPresentationState == .open,
              let popupPlayerVC = tabBar.popupContent as? PopupPlayerVC {
               popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: vc)
           } else {
               display(vc: vc)
           }
        } else if !self.isCollapsed {
            display(vc: vc)
        }
    }
    
    public func display(vc: UIViewController) {
        if self.isCollapsed {
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
            if self.isCollapsed {
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
                let searchVC = SideBarItems.search.controller
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

extension SplitVC: UISplitViewControllerDelegate {
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        setCorrectPlayerBarView(collapseMode: true)
    }
    
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        setCorrectPlayerBarView(collapseMode: false)
    }
}
