//
//  MusicFoldersVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.05.21.
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
import CoreData
import UIKit

class MusicFoldersVC: SingleFetchedResultsTableViewController<MusicFolderMO> {
  override var sceneTitle: String? { "Directories" }

  private var fetchedResultsController: MusicFolderFetchedResultsController!

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.musicFolders)

    fetchedResultsController = MusicFolderFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(placeholder: "Search in \"Directories\"")
    setNavBarTitle(title: "Directories")
    tableView.register(nibName: DirectoryTableCell.typeName)
    tableView.rowHeight = DirectoryTableCell.rowHeight
    tableView.estimatedRowHeight = DirectoryTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor
    resultUpdateHandler?.changesDidEnd = {
      self.updateContentUnavailable()
    }
  }

  func updateContentUnavailable() {
    if fetchedResultsController.fetchedObjects?.count ?? 0 == 0 {
      if fetchedResultsController.isSearchActive {
        contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
      } else {
        contentUnavailableConfiguration = emptyContentConfig
      }
    } else {
      contentUnavailableConfiguration = nil
    }
  }

  lazy var emptyContentConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .folder
    config.text = "No Directories"
    config.secondaryText = "Your directories will appear here."
    return config
  }()

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    updateContentUnavailable()
    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.getMeta(self.account.info).librarySyncer
        .syncMusicFolders()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Music Folders Sync", error: error)
    }}
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
    let musicFolder = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(folder: musicFolder)
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let musicFolder = fetchedResultsController.getWrappedEntity(at: indexPath)
    navigationController?.pushViewController(
      AppStoryboard.Main.segueToIndexes(account: account, musicFolder: musicFolder),
      animated: true
    )
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(searchText: searchText)
    tableView.reloadData()
    updateContentUnavailable()
  }
}
