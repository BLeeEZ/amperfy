//
//  PlaylistsVC.swift
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
import CoreData
import UIKit

class PlaylistsVC: SingleFetchedResultsTableViewController<PlaylistMO> {
  override var sceneTitle: String? { "Playlists" }

  private var fetchedResultsController: PlaylistFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  private var sortType: PlaylistSortType = .name

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.playlists)

    optionsButton = SortBarButton()

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
    setNavBarTitle(title: "Playlists")
    tableView.register(nibName: PlaylistTableCell.typeName)
    tableView.rowHeight = PlaylistTableCell.rowHeight
    tableView.estimatedRowHeight = PlaylistTableCell.rowHeight

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath)
    }
    playContextAtIndexPathCallback = { indexPath in
      let entity = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      return PlayContext(containable: entity)
    }
    swipeCallback = { indexPath, completionHandler in
      let playlist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      Task { @MainActor in
        do {
          try await playlist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: playlist))
      }
    }
  }

  func change(sortType: PlaylistSortType) {
    self.sortType = sortType
    appDelegate.storage.settings.playlistsSortSetting = sortType
    singleFetchedResultsController?.clearResults()
    fetchedResultsController = PlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType != .none
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController
    tableView.reloadData()
    updateRightBarButtonItems()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    if appDelegate.storage.settings.isOfflineMode {
      isEditing = false
    }
    updateRightBarButtonItems()
    guard appDelegate.storage.settings.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
    }}
  }

  func updateRightBarButtonItems() {
    var actions = [UIMenu]()
    actions.append(createSortButtonMenu())
    actions.append(createOptionsButtonMenu())
    optionsButton.menu = UIMenu(children: actions)
    #if targetEnvironment(macCatalyst)
      navigationItem.leftItemsSupplementBackButton = true
      navigationItem.rightBarButtonItem = optionsButton
      if appDelegate.storage.settings.isOnlineMode {
        navigationItem.leftBarButtonItem = editButtonItem
      }
    #else
      var barButtons = [UIBarButtonItem]()
      barButtons.append(optionsButton)
      if appDelegate.storage.settings.isOnlineMode {
        barButtons.append(editButtonItem)
      }
      navigationItem.rightBarButtonItems = barButtons
    #endif
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
    performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
  }

  // Override to support editing the table view.
  override func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    guard editingStyle == .delete else { return }
    let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
    let playlistId = playlist.id
    appDelegate.storage.main.library.deletePlaylist(playlist)
    appDelegate.storage.main.saveContext()

    Task { @MainActor in do {
      try await self.appDelegate.librarySyncer.syncUpload(playlistIdToDelete: playlistId)
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlist Upload Deletion", error: error)
    }}
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == Segues.toPlaylistDetail.rawValue {
      let vc = segue.destination as! PlaylistDetailVC
      let playlist = sender as? Playlist
      vc.playlist = playlist
    }
  }

  private func createSortButtonMenu() -> UIMenu {
    let sortByName = UIAction(
      title: "Name",
      image: sortType == .name ? .check : nil,
      handler: { _ in
        self.change(sortType: .name)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByLastTimePlayed = UIAction(
      title: "Last time played",
      image: sortType == .lastPlayed ? .check : nil,
      handler: { _ in
        self.change(sortType: .lastPlayed)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByChangeDate = UIAction(
      title: "Change date",
      image: sortType == .lastChanged ? .check : nil,
      handler: { _ in
        self.change(sortType: .lastChanged)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByDuration = UIAction(
      title: "Duration",
      image: sortType == .duration ? .check : nil,
      handler: { _ in
        self.change(sortType: .duration)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    return UIMenu(
      title: "Sort",
      image: .sort,
      options: [.displayInline],
      children: [sortByName, sortByLastTimePlayed, sortByChangeDate, sortByDuration]
    )
  }

  private func createOptionsButtonMenu() -> UIMenu {
    let fetchAllPlaylists = UIAction(title: "Sync All Playlists", image: .refresh, handler: { _ in
      Task { @MainActor in do {
        let playlistsIds = try await self.appDelegate.storage.async
          .performAndGet { asyncCompanion in
            let playlists = asyncCompanion.library.getPlaylists()
            return playlists.compactMap { $0.managedObject.objectID }
          }
        for moId in playlistsIds {
          let playlistMainMO = self.appDelegate.storage.main.context
            .object(with: moId) as! PlaylistMO
          let playlistMain = Playlist(
            library: self.appDelegate.storage.main.library,
            managedObject: playlistMainMO
          )
          try await playlistMain.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        }
        self.appDelegate.eventLogger.info(
          topic: "Sync All Playlists",
          message: "All playlists have been synced."
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Sync All Playlists", error: error)
      }}
    })
    return UIMenu(
      title: "Options",
      image: .sort,
      options: [.displayInline],
      children: [fetchAllPlaylists]
    )
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    Task { @MainActor in
      do {
        try await self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
      }
      self.refreshControl?.endRefreshing()
    }
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
