//
//  GenresVC.swift
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

class GenresVC: SingleFetchedResultsTableViewController<GenreMO> {
  override var sceneTitle: String? { "Genres" }

  private var fetchedResultsController: GenreFetchedResultsController!

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    appDelegate.userStatistics.visited(.genres)

    fetchedResultsController = GenreFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: true
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(
      placeholder: "Search in \"Genres\"",
      scopeButtonTitles: ["All", "Cached"],
      showSearchBarAtEnter: true
    )
    setNavBarTitle(title: "Genres")
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.rowHeight = GenericTableCell.rowHeightWithoutImage
    tableView.estimatedRowHeight = GenericTableCell.rowHeightWithoutImage
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
      let genre = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      Task { @MainActor in
        do {
          try await genre.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Genre Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: genre))
      }
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
    let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(container: genre, rootView: self)
    cell.entityImage.isHidden = true
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
    performSegue(withIdentifier: Segues.toGenreDetail.rawValue, sender: genre)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == Segues.toGenreDetail.rawValue {
      let vc = segue.destination as! GenreDetailVC
      let genre = sender as? Genre
      vc.genre = genre
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(
      searchText: searchText,
      onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1
    )
    tableView.reloadData()
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    guard appDelegate.storage.settings.isOnlineMode else {
      self.refreshControl?.endRefreshing()
      return
    }
    Task { @MainActor in
      do {
        try await AutoDownloadLibrarySyncer(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.librarySyncer,
          playableDownloadManager: self.appDelegate.playableDownloadManager
        )
        .syncNewestLibraryElements()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Genres Newest Elements Sync", error: error)
      }
      self.refreshControl?.endRefreshing()
    }
  }
}
