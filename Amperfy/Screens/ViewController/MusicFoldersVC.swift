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

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.musicFolders)

    fetchedResultsController = MusicFolderFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(placeholder: "Search in \"Directories\"")
    setNavBarTitle(title: "Directories")
    tableView.register(nibName: DirectoryTableCell.typeName)
    tableView.rowHeight = DirectoryTableCell.rowHeight
    tableView.estimatedRowHeight = DirectoryTableCell.rowHeight
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    guard appDelegate.storage.settings.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.librarySyncer.syncMusicFolders()
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
    performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: musicFolder)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == Segues.toDirectories.rawValue {
      let vc = segue.destination as! IndexesVC
      let musicFolder = sender as? MusicFolder
      vc.musicFolder = musicFolder
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(searchText: searchText)
    tableView.reloadData()
  }
}
