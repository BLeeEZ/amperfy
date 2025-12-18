//
//  DirectoriesVC.swift
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

class DirectoriesVC: MultiSourceTableViewController {
  override var sceneTitle: String? { directory.name }

  private var subdirectoriesFetchedResultsController: DirectorySubdirectoriesFetchedResultsController!
  private var songsFetchedResultsController: DirectorySongsFetchedResultsController!
  private var headerView: LibraryElementDetailTableHeaderView?
  let directory: Directory

  init(account: Account, directory: Directory) {
    self.directory = directory
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.directories)

    subdirectoriesFetchedResultsController = DirectorySubdirectoriesFetchedResultsController(
      for: directory,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    subdirectoriesFetchedResultsController.delegate = self
    songsFetchedResultsController = DirectorySongsFetchedResultsController(
      for: directory,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    songsFetchedResultsController.delegate = self

    configureSearchController(
      placeholder: "Directories and Songs",
      scopeButtonTitles: ["All", "Cached"]
    )
    setNavBarTitle(title: directory.name)
    tableView.register(nibName: DirectoryTableCell.typeName)
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: {
        "\(self.songsFetchedResultsController.fetchedObjects?.count ?? 0) Song\((self.songsFetchedResultsController.fetchedObjects?.count) == 1 ? "" : "s")"
      },
      playContextCb: { () in PlayContext(
        containable: self.directory,
        playables: self.songsFetchedResultsController
          .getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.user.isOfflineMode) ??
          []
      ) },
      player: appDelegate.player,
      isInfoAlwaysHidden: false
    )
    headerView = LibraryElementDetailTableHeaderView.createTableHeader(
      rootView: self,
      configuration: playShuffleInfoConfig
    )
    refreshHeaderView()

    containableAtIndexPathCallback = { indexPath in
      switch indexPath.section {
      case 0:
        let subdirectoryIndexPath = IndexPath(row: indexPath.row, section: 0)
        return self.subdirectoriesFetchedResultsController
          .getWrappedEntity(at: subdirectoryIndexPath)
      case 1:
        let songIndexPath = IndexPath(row: indexPath.row, section: 0)
        return self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
      default:
        return nil
      }
    }
    playContextAtIndexPathCallback = { indexPath in
      switch indexPath.section {
      case 0:
        let subdirectory = self.subdirectoriesFetchedResultsController
          .getWrappedEntity(at: IndexPath(
            row: indexPath.row,
            section: 0
          ))
        Task { @MainActor in
          do {
            try await subdirectory.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(self.account.info)
                .playableDownloadManager
            )
          } catch {
            self.appDelegate.eventLogger.report(topic: "Directory Sync", error: error)
          }
          self.refreshHeaderView()
        }
        return PlayContext(containable: subdirectory)
      case 1:
        let songIndexPath = IndexPath(row: indexPath.row, section: 0)
        return self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
      default:
        return nil
      }
    }
    swipeCallback = { indexPath, completionHandler in
      switch indexPath.section {
      case 0:
        let subdirectory = self.subdirectoriesFetchedResultsController
          .getWrappedEntity(at: IndexPath(
            row: indexPath.row,
            section: 0
          ))
        Task { @MainActor in
          do {
            try await subdirectory.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(self.account.info)
                .playableDownloadManager
            )
          } catch {
            self.appDelegate.eventLogger.report(topic: "Directory Sync", error: error)
          }
          completionHandler(SwipeActionContext(containable: subdirectory))
          self.refreshHeaderView()
        }
      case 1:
        let songIndexPath = IndexPath(row: indexPath.row, section: 0)
        let song = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        let playContext = self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
        completionHandler(SwipeActionContext(containable: song, playContext: playContext))
      default:
        completionHandler(nil)
      }
    }
    resultUpdateHandler?.changesDidEnd = {
      self.updateContentUnavailable()
    }
  }

  func updateContentUnavailable() {
    if subdirectoriesFetchedResultsController.fetchedObjects?.count ?? 0 == 0,
       songsFetchedResultsController.fetchedObjects?.count ?? 0 == 0 {
      if subdirectoriesFetchedResultsController.isSearchActive {
        contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
      } else {
        contentUnavailableConfiguration = emptyContentConfig
      }
      headerView?.isHidden = true
    } else {
      contentUnavailableConfiguration = nil
      headerView?.isHidden = false
    }
  }

  lazy var emptyContentConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .folder
    config.text = "No Directories or Songs"
    config.secondaryText = "Your directories and songs will appear here."
    return config
  }()

  func refreshHeaderView() {
    headerView?.refresh()
    if !directory.songs.isEmpty {
      headerView?.activate()
    } else {
      headerView?.deactivate()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = false
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    subdirectoriesFetchedResultsController?.delegate = self
    songsFetchedResultsController?.delegate = self
    updateContentUnavailable()

    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in
      do {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer
          .sync(directory: directory)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Directories Sync", error: error)
      }
      self.refreshHeaderView()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    subdirectoriesFetchedResultsController?.delegate = nil
    songsFetchedResultsController?.delegate = nil
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
    guard let songs = songsFetchedResultsController
      .getContextSongs(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    else { return nil }
    let selectedSong = songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
    guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
    return PlayContext(name: directory.name, index: playContextIndex, playables: songs)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell),
          indexPath.section == 1
    else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    2
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return subdirectoriesFetchedResultsController.sections?[0].numberOfObjects ?? 0
    case 1:
      return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0
    default:
      return 0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
      let cellDirectory = subdirectoriesFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      cell.display(directory: cellDirectory)
      return cell
    case 1:
      let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
      let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
      return cell
    default:
      return UITableViewCell()
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    switch indexPath.section {
    case 0:
      return DirectoryTableCell.rowHeight
    case 1:
      return PlayableTableCell.rowHeight
    default:
      return 0.0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    estimatedHeightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    switch indexPath.section {
    case 0:
      return DirectoryTableCell.rowHeight
    case 1:
      return PlayableTableCell.rowHeight
    default:
      return 0.0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  )
    -> UISwipeActionsConfiguration? {
    guard indexPath.section == 1 else { return nil }
    return super.tableView(tableView, leadingSwipeActionsConfigurationForRowAt: indexPath)
  }

  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  )
    -> UISwipeActionsConfiguration? {
    guard indexPath.section == 1 else { return nil }
    return super.tableView(tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard indexPath.section == 0, let navController = navigationController else { return }

    let selectedDirectory = subdirectoriesFetchedResultsController.getWrappedEntity(at: IndexPath(
      row: indexPath.row,
      section: 0
    ))
    navController.pushViewController(
      AppStoryboard.Main.segueToDirectories(account: account, directory: selectedDirectory),
      animated: true
    )
  }

  override func updateSearchResults(for searchController: UISearchController) {
    guard let searchText = searchController.searchBar.text else { return }
    if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 0 {
      subdirectoriesFetchedResultsController.search(searchText: searchText)
      songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
    } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
      subdirectoriesFetchedResultsController.search(searchText: searchText)
      songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
    } else {
      subdirectoriesFetchedResultsController.showAllResults()
      songsFetchedResultsController.showAllResults()
    }
    tableView.reloadData()
    headerView?.refresh()
    updateContentUnavailable()
  }

  override func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange anObject: Any,
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    var section = 0
    switch controller {
    case subdirectoriesFetchedResultsController.fetchResultsController:
      section = 0
    case songsFetchedResultsController.fetchResultsController:
      section = 1
    default:
      return
    }

    resultUpdateHandler?.applyChangesOfMultiRowType(
      controller,
      didChange: anObject,
      determinedSection: section,
      at: indexPath,
      for: type,
      newIndexPath: newIndexPath
    )
  }

  override func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange sectionInfo: NSFetchedResultsSectionInfo,
    atSectionIndex sectionIndex: Int,
    for type: NSFetchedResultsChangeType
  ) {}
}
