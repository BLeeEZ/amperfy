//
//  PlaylistAddPlaylistsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.12.24.
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
import CoreData
import UIKit

class PlaylistAddPlaylistsVC: SingleFetchedResultsTableViewController<PlaylistMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? { "Playlists" }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: PlaylistFetchedResultsController!
  private var sortType: PlaylistSortType = .name
  private var doneButton: UIBarButtonItem!

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    change(sortType: appDelegate.storage.settings.playlistsSortSetting)

    var searchTiles: [String]? = nil
    if appDelegate.backendApi.selectedApi == .ampache {
      searchTiles = ["All", "Cached", "User", "Smart"]
    } else if appDelegate.backendApi.selectedApi == .subsonic {
      searchTiles = ["All", "Cached"]
    }
    configureSearchController(
      placeholder: "Search in \"Playlists\"",
      scopeButtonTitles: searchTiles,
      showSearchBarAtEnter: true
    )
    tableView.register(nibName: PlaylistTableCell.typeName)
    tableView.rowHeight = PlaylistTableCell.rowHeight
    tableView.estimatedRowHeight = PlaylistTableCell.rowHeight
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()

    guard appDelegate.storage.settings.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
    }}
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  func change(sortType: PlaylistSortType) {
    self.sortType = sortType
    appDelegate.storage.settings.playlistsSortSetting = sortType
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = PlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType != .none
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController
    tableView.reloadData()
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
    let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(playlist: playlist, rootView: self)
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
    let nextVC = PlaylistAddPlaylistDetailVC()
    nextVC.playlist = playlist
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    let playlistSearchCategory = PlaylistSearchCategory(
      rawValue: searchController.searchBar
        .selectedScopeButtonIndex
    ) ?? PlaylistSearchCategory.defaultValue
    fetchedResultsController.search(
      searchText: searchText,
      playlistSearchCategory: playlistSearchCategory
    )
    tableView.reloadData()
  }
}
