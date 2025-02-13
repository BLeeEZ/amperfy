//
//  PodcastsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.06.21.
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

class PodcastsVC: MultiSourceTableViewController {
  override var sceneTitle: String? { "Podcasts" }

  private var podcastsFetchedResultsController: PodcastFetchedResultsController!
  private var episodesFetchedResultsController: PodcastEpisodesReleaseDateFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  private var showType: PodcastsShowType = .podcasts

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.podcasts)

    optionsButton = SortBarButton()

    podcastsFetchedResultsController = PodcastFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    episodesFetchedResultsController = PodcastEpisodesReleaseDateFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )

    configureSearchController(
      placeholder: "Search in \"Podcasts\"",
      scopeButtonTitles: ["All", "Cached"],
      showSearchBarAtEnter: true
    )
    setNavBarTitle(title: "Podcasts")
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: PodcastEpisodeTableCell.typeName)

    swipeDisplaySettings.playContextTypeOfElements = .podcast
    containableAtIndexPathCallback = { indexPath in
      switch self.showType {
      case .podcasts:
        return self.podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
      case .episodesSortedByReleaseDate:
        return self.episodesFetchedResultsController.getWrappedEntity(at: indexPath)
      }
    }
    playContextAtIndexPathCallback = { indexPath in
      switch self.showType {
      case .podcasts:
        let entity = self.podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
        return PlayContext(containable: entity)
      case .episodesSortedByReleaseDate:
        let entity = self.episodesFetchedResultsController.getWrappedEntity(at: indexPath)
        return PlayContext(containable: entity)
      }
    }
    swipeCallback = { indexPath, completionHandler in
      switch self.showType {
      case .podcasts:
        let podcast = self.podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
        Task { @MainActor in
          do {
            try await podcast.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.librarySyncer,
              playableDownloadManager: self.appDelegate.playableDownloadManager
            )
          } catch {
            self.appDelegate.eventLogger.report(topic: "Podcasts Sync", error: error)
          }
          completionHandler(SwipeActionContext(containable: podcast))
        }
      case .episodesSortedByReleaseDate:
        let episode = self.episodesFetchedResultsController.getWrappedEntity(at: indexPath)
        completionHandler(SwipeActionContext(containable: episode))
      }
    }

    showType = appDelegate.storage.settings.podcastsShowSetting
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    switch showType {
    case .podcasts:
      podcastsFetchedResultsController?.delegate = self
    case .episodesSortedByReleaseDate:
      episodesFetchedResultsController?.delegate = self
    }

    updateRightBarButtonItems()
    syncFromServer()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    podcastsFetchedResultsController?.delegate = nil
    episodesFetchedResultsController?.delegate = nil
  }

  func updateRightBarButtonItems() {
    optionsButton.menu = createSortButtonMenu()
    navigationItem.rightBarButtonItem = optionsButton
  }

  func syncFromServer() {
    if appDelegate.storage.settings.isOnlineMode {
      Task { @MainActor in do {
        let _ = try await AutoDownloadLibrarySyncer(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.librarySyncer,
          playableDownloadManager: self.appDelegate
            .playableDownloadManager
        )
        .syncNewestPodcastEpisodes()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Podcasts Sync", error: error)
      }}
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch showType {
    case .podcasts:
      return podcastsFetchedResultsController.sections?[0].numberOfObjects ?? 0
    case .episodesSortedByReleaseDate:
      return episodesFetchedResultsController.sections?[0].numberOfObjects ?? 0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    switch showType {
    case .podcasts:
      let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
      let podcast = podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
      cell.display(container: podcast, rootView: self)
      return cell
    case .episodesSortedByReleaseDate:
      let cell: PodcastEpisodeTableCell = dequeueCell(for: tableView, at: indexPath)
      let episode = episodesFetchedResultsController.getWrappedEntity(at: indexPath)
      cell.display(episode: episode, rootView: self)
      return cell
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    switch showType {
    case .podcasts:
      return GenericTableCell.rowHeight
    case .episodesSortedByReleaseDate:
      return PodcastEpisodeTableCell.rowHeight
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch showType {
    case .podcasts:
      let podcast = podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
      performSegue(withIdentifier: Segues.toPodcastDetail.rawValue, sender: podcast)
    case .episodesSortedByReleaseDate:
      break
    }
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == Segues.toPodcastDetail.rawValue {
      let vc = segue.destination as! PodcastDetailVC
      let podcast = sender as? Podcast
      vc.podcast = podcast
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    switch showType {
    case .podcasts:
      let searchText = searchController.searchBar.text ?? ""
      podcastsFetchedResultsController.search(
        searchText: searchText,
        onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1
      )
      tableView.reloadData()
    case .episodesSortedByReleaseDate:
      let searchText = searchController.searchBar.text ?? ""
      episodesFetchedResultsController.search(
        searchText: searchText,
        onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1
      )
      tableView.reloadData()
    }
  }

  override func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange anObject: Any,
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    switch showType {
    case .podcasts:
      if podcastsFetchedResultsController.isOneOfThis(controller) {
        super.controller(
          controller,
          didChange: anObject,
          at: indexPath,
          for: type,
          newIndexPath: newIndexPath
        )
      }
    case .episodesSortedByReleaseDate:
      if episodesFetchedResultsController.fetchResultsController == controller {
        super.controller(
          controller,
          didChange: anObject,
          at: indexPath,
          for: type,
          newIndexPath: newIndexPath
        )
      }
    }
  }

  private func createSortButtonMenu() -> UIMenu {
    let podcastsSortByName = UIAction(
      title: "Podcasts sorted by name",
      image: showType == .podcasts ? .check : nil,
      handler: { _ in
        self.showType = .podcasts
        self.appDelegate.storage.settings.podcastsShowSetting = .podcasts
        self.syncFromServer()
        self.updateRightBarButtonItems()
        self.episodesFetchedResultsController.delegate = nil
        self.updateSearchResults(for: self.searchController)
        self.podcastsFetchedResultsController.delegate = self
      }
    )
    let episodesSortByReleaseDate = UIAction(
      title: "Episodes sorted by release date",
      image: showType == .episodesSortedByReleaseDate ? .check : nil,
      handler: { _ in
        self.showType = .episodesSortedByReleaseDate
        self.appDelegate.storage.settings.podcastsShowSetting = .episodesSortedByReleaseDate
        self.syncFromServer()
        self.updateRightBarButtonItems()
        self.podcastsFetchedResultsController.delegate = nil
        self.updateSearchResults(for: self.searchController)
        self.episodesFetchedResultsController.delegate = self
      }
    )
    return UIMenu(children: [podcastsSortByName, episodesSortByReleaseDate])
  }
}
