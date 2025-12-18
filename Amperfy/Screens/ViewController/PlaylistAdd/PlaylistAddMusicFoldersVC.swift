//
//  PlaylistAddMusicFoldersVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.12.24.
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

class PlaylistAddMusicFoldersVC: SingleFetchedResultsTableViewController<MusicFolderMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? { "Directories" }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: MusicFolderFetchedResultsController!
  private var doneButton: UIBarButtonItem!

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    fetchedResultsController = MusicFolderFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(placeholder: "Search in \"Directories\"")
    tableView.register(nibName: DirectoryTableCell.typeName)
    tableView.rowHeight = DirectoryTableCell.rowHeight
    tableView.estimatedRowHeight = DirectoryTableCell.rowHeight
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()

    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.getMeta(account.info).librarySyncer.syncMusicFolders()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Music Folders Sync", error: error)
    }}
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
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

    let nextVC = PlaylistAddIndexesVC(account: account, musicFolder: musicFolder)
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(searchText: searchText)
    tableView.reloadData()
  }
}
