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

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.podcasts)

    optionsButton = UIBarButtonItem.createSortBarButton()

    podcastsFetchedResultsController = PodcastFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      isGroupedInAlphabeticSections: false
    )
    episodesFetchedResultsController = PodcastEpisodesReleaseDateFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      isGroupedInAlphabeticSections: false
    )

    configureSearchController(
      placeholder: "Search in \"Podcasts\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    setNavBarTitle(title: "Podcasts")
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: PodcastEpisodeTableCell.typeName)
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor

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
              librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(self.account.info)
                .playableDownloadManager
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

    showType = appDelegate.storage.settings.user.podcastsShowSetting

    resultUpdateHandler?.changesDidEnd = {
      self.updateContentUnavailable()
    }
  }

  func updateContentUnavailable() {
    switch showType {
    case .podcasts:
      if podcastsFetchedResultsController.fetchedObjects?.count ?? 0 == 0 {
        if podcastsFetchedResultsController.isSearchActive {
          contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
        } else {
          contentUnavailableConfiguration = emptyPodcastConfig
        }
      } else {
        contentUnavailableConfiguration = nil
      }
    case .episodesSortedByReleaseDate:
      if episodesFetchedResultsController.fetchedObjects?.count ?? 0 == 0 {
        if episodesFetchedResultsController.isSearchActive {
          contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
        } else {
          contentUnavailableConfiguration = emptyEpisodeConfig
        }
      } else {
        contentUnavailableConfiguration = nil
      }
    }
  }

  lazy var emptyPodcastConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .podcast
    config.text = "No Podcasts"
    config.secondaryText = "Your podcasts will appear here."
    return config
  }()

  lazy var emptyEpisodeConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .podcastEpisode
    config.text = "No Podcast Episodes"
    config.secondaryText = "Your podcast episodes will appear here."
    return config
  }()

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    switch showType {
    case .podcasts:
      podcastsFetchedResultsController?.delegate = self
    case .episodesSortedByReleaseDate:
      episodesFetchedResultsController?.delegate = self
    }

    updateRightBarButtonItems()
    syncFromServer()
    updateContentUnavailable()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    podcastsFetchedResultsController?.delegate = nil
    episodesFetchedResultsController?.delegate = nil
  }

  func updateRightBarButtonItems() {
    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = createSortButtonMenu()
    navigationItem.rightBarButtonItem = optionsButton
  }

  func syncFromServer() {
    if appDelegate.storage.settings.user.isOnlineMode {
      Task { @MainActor in do {
        let _ = try await AutoDownloadLibrarySyncer(
          storage: self.appDelegate.storage,
          account: self.account,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
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
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToPodcastDetail(account: account, podcast: podcast),
        animated: true
      )
    case .episodesSortedByReleaseDate:
      break
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
    updateContentUnavailable()
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
        self.appDelegate.storage.settings.user.podcastsShowSetting = .podcasts
        self.syncFromServer()
        self.updateRightBarButtonItems()
        self.episodesFetchedResultsController.delegate = nil
        self.updateSearchResults(for: self.searchController)
        self.podcastsFetchedResultsController.delegate = self
        self.updateContentUnavailable()
      }
    )
    let episodesSortByReleaseDate = UIAction(
      title: "Episodes sorted by release date",
      image: showType == .episodesSortedByReleaseDate ? .check : nil,
      handler: { _ in
        self.showType = .episodesSortedByReleaseDate
        self.appDelegate.storage.settings.user.podcastsShowSetting = .episodesSortedByReleaseDate
        self.syncFromServer()
        self.updateRightBarButtonItems()
        self.podcastsFetchedResultsController.delegate = nil
        self.updateSearchResults(for: self.searchController)
        self.episodesFetchedResultsController.delegate = self
        self.updateContentUnavailable()
      }
    )
    return UIMenu(children: [podcastsSortByName, episodesSortByReleaseDate])
  }
}
