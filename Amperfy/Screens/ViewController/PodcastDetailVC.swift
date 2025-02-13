//
//  PodcastDetailVC.swift
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
import UIKit

class PodcastDetailVC: SingleFetchedResultsTableViewController<PodcastEpisodeMO> {
  override var sceneTitle: String? { podcast.name }

  var podcast: Podcast!
  var episodeToScrollTo: PodcastEpisode?
  private var fetchedResultsController: PodcastEpisodesFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  private var detailOperationsView: GenericDetailTableHeader?

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    optionsButton = OptionsBarButton()

    appDelegate.userStatistics.visited(.podcastDetail)
    fetchedResultsController = PodcastEpisodesFetchedResultsController(
      forPodcast: podcast,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(
      placeholder: "Search in \"Podcast\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: PodcastEpisodeTableCell.typeName)
    tableView.rowHeight = PodcastEpisodeTableCell.rowHeight
    tableView.estimatedRowHeight = PodcastEpisodeTableCell.rowHeight

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: { "\(self.podcast.episodeCount) Episode\(self.podcast.episodeCount == 1 ? "" : "s")"
      },
      playContextCb: { () in
        let context = self.fetchedResultsController
          .getContextPodcastEpisodes(
            onlyCachedSongs: self.appDelegate.storage.settings
              .isOfflineMode
          )
        let newestEpisode = context?.first
        let playables = newestEpisode != nil ? [newestEpisode!] : [AbstractPlayable]()
        return PlayContext(containable: self.podcast, playables: playables)
      },
      player: appDelegate.player,
      isInfoAlwaysHidden: false,
      customPlayName: "Newest Episode",
      isShuffleHidden: true
    )
    let detailHeaderConfig = DetailHeaderConfiguration(
      entityContainer: podcast,
      rootView: self,
      tableView: tableView,
      playShuffleInfoConfig: playShuffleInfoConfig,
      descriptionText: podcast.depiction
    )
    detailOperationsView = GenericDetailTableHeader
      .createTableHeader(configuration: detailHeaderConfig)
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )
    optionsButton.menu = UIMenu.lazyMenu {
      EntityPreviewActionBuilder(container: self.podcast, on: self).createMenu()
    }
    navigationItem.rightBarButtonItem = optionsButton

    swipeDisplaySettings.playContextTypeOfElements = .podcast
    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath)
    }
    playContextAtIndexPathCallback = { indexPath in
      let entity = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      return PlayContext(containable: entity)
    }
    swipeCallback = { indexPath, completionHandler in
      let episode = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      completionHandler(SwipeActionContext(containable: episode))
    }
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    Task { @MainActor in
      do {
        try await podcast.fetch(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.librarySyncer,
          playableDownloadManager: self.appDelegate.playableDownloadManager
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
      }
      self.detailOperationsView?.refresh()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    defer { episodeToScrollTo = nil }
    guard let episodeToScrollTo = episodeToScrollTo,
          let indexPath = fetchedResultsController.fetchResultsController
          .indexPath(forObject: episodeToScrollTo.managedObject)
    else { return }
    tableView.scrollToRow(at: indexPath, at: .top, animated: true)
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: PodcastEpisodeTableCell = dequeueCell(for: tableView, at: indexPath)
    let episode = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(episode: episode, rootView: self)
    return cell
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController.search(
      searchText: searchController.searchBar.text ?? "",
      onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1
    )
    tableView.reloadData()
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    Task { @MainActor in
      do {
        try await self.appDelegate.librarySyncer.sync(podcast: self.podcast)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
      }
      self.detailOperationsView?.refresh()
      self.tableView.visibleCells.forEach { ($0 as! PodcastEpisodeTableCell).refresh() }
      self.refreshControl?.endRefreshing()
    }
  }
}
