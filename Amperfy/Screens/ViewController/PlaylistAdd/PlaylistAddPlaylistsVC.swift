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

// MARK: - PlaylistAddPlaylistsDiffableDataSource

class PlaylistAddPlaylistsDiffableDataSource: BasicUITableViewDiffableDataSource {
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    false
  }

  func playlistAt(indexPath: IndexPath) -> Playlist? {
    let objectID = itemIdentifier(for: indexPath)
    guard let objectID,
          let object = try? appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistMO = object as? PlaylistMO
    else {
      return nil
    }

    let playlist = Playlist(
      library: appDelegate.storage.main.library,
      managedObject: playlistMO
    )
    return playlist
  }
}

// MARK: - PlaylistAddPlaylistsVC

class PlaylistAddPlaylistsVC: SingleSnapshotFetchedResultsTableViewController<PlaylistMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? { "Playlists" }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: PlaylistFetchedResultsController!
  private var sortType: PlaylistSortType = .name
  private var doneButton: UIBarButtonItem!

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      PlaylistAddPlaylistsDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistMO = object as? PlaylistMO
        else {
          return UITableViewCell()
        }
        let playlist = Playlist(
          library: self.appDelegate.storage.main.library,
          managedObject: playlistMO
        )
        return self.createCell(tableView, forRowAt: indexPath, playlist: playlist)
      }
    return source
  }

  func playlistAt(indexPath: IndexPath) -> Playlist? {
    (diffableDataSource as? PlaylistAddPlaylistsDiffableDataSource)?
      .playlistAt(indexPath: indexPath)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    change(sortType: appDelegate.storage.settings.user.playlistsSortSetting)

    var searchTiles: [String]? = nil
    if account.apiType.asServerApiType == .ampache {
      searchTiles = ["All", "Cached", "User", "Smart"]
    } else if account.apiType.asServerApiType == .subsonic {
      searchTiles = ["All", "Cached"]
    }
    configureSearchController(
      placeholder: "Search in \"Playlists\"",
      scopeButtonTitles: searchTiles
    )
    tableView.register(nibName: PlaylistTableCell.typeName)
    tableView.rowHeight = PlaylistTableCell.rowHeight
    tableView.estimatedRowHeight = PlaylistTableCell.rowHeight
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
      try await self.appDelegate.getMeta(account.info).librarySyncer
        .syncDownPlaylistsWithoutSongs()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
    }}
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  func change(sortType: PlaylistSortType) {
    self.sortType = sortType
    appDelegate.storage.settings.user.playlistsSortSetting = sortType
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = PlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType != .none
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()
    tableView.reloadData()
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    playlist: Playlist
  )
    -> UITableViewCell {
    let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
    cell.display(playlist: playlist, rootView: self)
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let playlist = playlistAt(indexPath: indexPath) else { return }
    let nextVC = PlaylistAddPlaylistDetailVC(account: account, playlist: playlist)
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
