//
//  SideBarVC.swift
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

let kTabbarSafeAreaTop = 52.0

class SideBarVC: KeyCommandCollectionViewController {

    private var offsetData: [LibraryNavigatorItem] = {
        return [LibraryNavigatorItem(title: "Search", tab: .search),
                LibraryNavigatorItem(title: "Settings", tab: .settings),
                LibraryNavigatorItem(title: "Library", isInteractable: false)]
    }()

    lazy var layoutConfig = {
        return UICollectionLayoutListConfiguration(appearance: .sidebar)
    }()
    lazy var libraryItemConfigurator = LibraryNavigatorConfigurator(
        offsetData: offsetData,
        librarySettings: appDelegate.storage.settings.libraryDisplaySettings,
        layoutConfig: self.layoutConfig, pressedOnLibraryItemCB: self.pushedOn
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = false
        libraryItemConfigurator.viewDidLoad(navigationItem: navigationItem, collectionView: collectionView)

        #if targetEnvironment(macCatalyst)
        //self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.navigationBar.addObserver(self, forKeyPath: "center", options: [.new], context: nil)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        guard keyPath == "center", 
                let navbar = object as? UINavigationBar,
                let newCenter = change?[NSKeyValueChangeKey.newKey] as? CGPoint else { return }
        let dt = newCenter.y - kTabbarSafeAreaTop
        self.collectionView.contentInset.top = min(0, -dt)
        navbar.frame.origin.y -= dt
    }
    #endif

    override func viewDidAppear(_ animated: Bool) {
        self.becomeFirstResponder()
        libraryItemConfigurator.viewDidAppear(navigationItem: navigationItem, collectionView: collectionView)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.resignFirstResponder()
    }
    
    public func pushedOn(selectedItem: LibraryNavigatorItem) {
        guard let splitVC = self.splitViewController as? SplitVC,
              !splitVC.isCollapsed
        else { return }
        
        if splitVC.displayMode == .oneOverSecondary {
            splitVC.hide(.primary)
        }

        if let libraryItem = selectedItem.library {
            splitVC.pushReplaceNavLibrary(vc: libraryItem.controller(settings: appDelegate.storage.settings))
        } else if let libraryItem = selectedItem.tab {
            if libraryItem == .settings {
                let vc = libraryItem.controller
                vc.view.backgroundColor = .secondarySystemBackground
                splitVC.pushReplaceNavLibrary(vc: vc)
            } else {
                splitVC.pushReplaceNavLibrary(vc: libraryItem.controller)
            }
        }
    }

}
