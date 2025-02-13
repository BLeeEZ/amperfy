//
//  LibraryVC.swift
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

@MainActor
class LibraryVC: KeyCommandCollectionViewController {
  private var offsetData = [LibraryNavigatorItem]()

  lazy var layoutConfig = {
    var config = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
    config.backgroundColor = .systemBackground
    return config
  }()

  lazy var libraryItemConfigurator = LibraryNavigatorConfigurator(
    offsetData: offsetData,
    librarySettings: appDelegate.storage.settings.libraryDisplaySettings,
    layoutConfig: self.layoutConfig,
    pressedOnLibraryItemCB: self.pushedOn
  )

  override func viewDidLoad() {
    super.viewDidLoad()
    libraryItemConfigurator.viewDidLoad(
      navigationItem: navigationItem,
      collectionView: collectionView
    )
  }

  public func pushedOn(selectedItem: LibraryNavigatorItem) {
    guard let splitVC = splitViewController as? SplitVC,
          splitVC.isCollapsed,
          let libraryItem = selectedItem.library
    else { return }
    splitVC
      .pushReplaceNavLibrary(vc: libraryItem.controller(settings: appDelegate.storage.settings))
  }
}
