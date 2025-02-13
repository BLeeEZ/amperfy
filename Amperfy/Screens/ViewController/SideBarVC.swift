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

import AmperfyKit
import UIKit

class SideBarVC: KeyCommandCollectionViewController {
  private var offsetData: [LibraryNavigatorItem] = {
    #if targetEnvironment(macCatalyst)
      return [
        LibraryNavigatorItem(title: "Search", tab: .search),
        LibraryNavigatorItem(title: "Library", isInteractable: false),
      ]
    #else
      return [
        LibraryNavigatorItem(title: "Search", tab: .search),
        LibraryNavigatorItem(title: "Settings", tab: .settings),
        LibraryNavigatorItem(title: "Library", isInteractable: false),
      ]
    #endif
  }()

  lazy var layoutConfig = UICollectionLayoutListConfiguration(appearance: .sidebar)
  lazy var libraryItemConfigurator = LibraryNavigatorConfigurator(
    offsetData: offsetData,
    librarySettings: appDelegate.storage.settings.libraryDisplaySettings,
    layoutConfig: self.layoutConfig, pressedOnLibraryItemCB: self.pushedOn
  )

  override func viewDidLoad() {
    super.viewDidLoad()

    clearsSelectionOnViewWillAppear = false
    libraryItemConfigurator.viewDidLoad(
      navigationItem: navigationItem,
      collectionView: collectionView
    )
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    becomeFirstResponder()
    libraryItemConfigurator.viewIsAppearing(
      navigationItem: navigationItem,
      collectionView: collectionView
    )
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    resignFirstResponder()
  }

  public func pushedOn(selectedItem: LibraryNavigatorItem) {
    guard let splitVC = splitViewController as? SplitVC,
          !splitVC.isCollapsed
    else { return }

    if splitVC.displayMode == .oneOverSecondary {
      splitVC.hide(.primary)
    }

    if let libraryItem = selectedItem.library {
      splitVC
        .pushReplaceNavLibrary(vc: libraryItem.controller(settings: appDelegate.storage.settings))
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
