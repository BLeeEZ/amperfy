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
import CoreData
import UIKit

// MARK: - SideBarVC

class SideBarVC: KeyCommandCollectionViewController {
  private let account: Account!
  private var pinnedPlaylistsFetchedResultsController: PinnedPlaylistFetchedResultsController!
  private let pinnedPlaylistsHeader = LibraryNavigatorItem(
    title: "Pinned",
    isInteractable: false
  )
  private var pinnedPlaylistItems = [NSManagedObjectID: LibraryNavigatorItem]()

  init(collectionViewLayout: UICollectionViewLayout, account: Account) {
    self.account = account
    super.init(collectionViewLayout: collectionViewLayout)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var offsetData: [LibraryNavigatorItem] = {
    [
      LibraryNavigatorItem(title: "Search", tab: .search),
      LibraryNavigatorItem(title: "Home", tab: .home),
      LibraryNavigatorItem(title: "Library", isInteractable: false),
    ]
  }()

  lazy var layoutConfig = UICollectionLayoutListConfiguration(appearance: .sidebar)
  lazy var libraryItemConfigurator = LibraryNavigatorConfigurator(
    account: account, offsetData: offsetData,
    librarySettings: appDelegate.storage.settings.accounts.getSetting(self.account.info)
      .read
      .libraryDisplaySettings,
    layoutConfig: self.layoutConfig, pressedOnLibraryItemCB: self.pushedOn
  )

  override func viewDidLoad() {
    super.viewDidLoad()

    clearsSelectionOnViewWillAppear = false
    configurePinnedPlaylists()
    libraryItemConfigurator.viewDidLoad(
      navigationItem: navigationItem,
      collectionView: collectionView
    )
    // hard top border -> other glass effect is to big and covers top sidebar elements
    collectionView.topEdgeEffect.style = .hard
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

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let topInsetCorrection = 55.0 - collectionView.safeAreaInsets.top
    collectionView.contentInset = .init(top: topInsetCorrection, left: 0, bottom: 0, right: 0)
  }

  public func pushedOn(selectedItem: LibraryNavigatorItem) {
    guard let splitVC = splitViewController as? SplitVC,
          !splitVC.isCollapsed
    else { return }

    if splitVC.displayMode == .oneOverSecondary {
      splitVC.hide(.primary)
    }

    if let libraryItem = selectedItem.library {
      AppDelegate.mainWindowHostVC?
        .pushLibraryCategory(vc: libraryItem.controller(
          account: account,
          settings: appDelegate.storage.settings
        ))
    } else if let libraryItem = selectedItem.tab {
      AppDelegate.mainWindowHostVC?.pushTabCategory(tabCategory: libraryItem)
    } else if let objectID = selectedItem.playlistObjectID,
              let managedObject = try? appDelegate.storage.main.context
              .existingObject(with: objectID),
              let playlistMO = managedObject as? PlaylistMO {
      let playlist = Playlist(
        library: appDelegate.storage.main.library,
        managedObject: playlistMO
      )
      AppDelegate.mainWindowHostVC?.pushLibraryCategory(
        vc: AppStoryboard.Main.segueToPlaylistDetail(account: account, playlist: playlist)
      )
    }
  }

  private func configurePinnedPlaylists() {
    pinnedPlaylistsFetchedResultsController = PinnedPlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      account: account
    )
    pinnedPlaylistsFetchedResultsController.delegate = self
    pinnedPlaylistsFetchedResultsController.fetch()
    updatePinnedPlaylists()
  }

  private func updatePinnedPlaylists() {
    let previousItems = pinnedPlaylistItems
    let playlists = pinnedPlaylistsFetchedResultsController.fetchedObjects?.map {
      Playlist(library: appDelegate.storage.main.library, managedObject: $0)
    } ?? []

    pinnedPlaylistItems = Dictionary(uniqueKeysWithValues: playlists.map { playlist in
      let objectID = playlist.managedObject.objectID
      let item = previousItems[objectID].flatMap { existingItem in
        existingItem.title == playlist.name ? existingItem : nil
      } ?? LibraryNavigatorItem(
        title: playlist.name,
        playlistObjectID: objectID
      )
      return (objectID, item)
    })

    let playlistItems = playlists.compactMap { pinnedPlaylistItems[$0.managedObject.objectID] }
    let additionalData = playlistItems.isEmpty ? [] : [pinnedPlaylistsHeader] + playlistItems
    libraryItemConfigurator.updateAdditionalData(additionalData)
  }
}

extension SideBarVC: @preconcurrency NSFetchedResultsControllerDelegate {
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    MainActor.assumeIsolated {
      guard controller == pinnedPlaylistsFetchedResultsController.fetchResultsController else {
        return
      }
      updatePinnedPlaylists()
    }
  }
}
