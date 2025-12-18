//
//  SongsVC.swift
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

class SongsVC: SingleFetchedResultsTableViewController<SongMO> {
  override var sceneTitle: String? {
    switch displayFilter {
    case .all, .newest, .recent: "Songs"
    case .favorites: "Favorite Songs"
    }
  }

  private var fetchedResultsController: SongsFetchedResultsController!
  private var detailHeaderView: LibraryElementDetailTableHeaderView?
  private var optionsButton: UIBarButtonItem!
  public var displayFilter: DisplayCategoryFilter = .all
  private var sortType: SongElementSortType = .name
  private var filterTitle = "Songs"

  private static var maxPlayContextCount = 40

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    appDelegate.userStatistics.visited(.songs)

    optionsButton = UIBarButtonItem.createOptionsBarButton()

    applyFilter()
    configureSearchController(
      placeholder: "Search in \"\(filterTitle)\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.backgroundColor = .backgroundColor

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: {
        "\(self.fetchedResultsController.fetchedObjects?.count ?? 0) Song\((self.fetchedResultsController.fetchedObjects?.count ?? 0) == 1 ? "" : "s")"
      },
      playContextCb: handleHeaderPlay,
      player: appDelegate.player,
      isInfoAlwaysHidden: false,
      shuffleContextCb: handleHeaderShuffle
    )
    detailHeaderView = LibraryElementDetailTableHeaderView.createTableHeader(
      rootView: self,
      configuration: playShuffleInfoConfig
    )
    #if !targetEnvironment(macCatalyst)
      refreshControl?.addTarget(
        self,
        action: #selector(Self.handleRefresh),
        for: UIControl.Event.valueChanged
      )
    #endif

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath)
    }
    playContextAtIndexPathCallback = convertIndexPathToPlayContext
    swipeCallback = { indexPath, completionHandler in
      let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
      completionHandler(SwipeActionContext(containable: song, playContext: playContext))
    }
    resultUpdateHandler?.changesDidEnd = {
      self.updateContentUnavailable()
    }
  }

  func updateContentUnavailable() {
    if fetchedResultsController.fetchedObjects?.count ?? 0 == 0 {
      if fetchedResultsController.isSearchActive {
        contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
      } else {
        contentUnavailableConfiguration = emptyContentConfig
      }
      detailHeaderView?.isHidden = true
    } else {
      contentUnavailableConfiguration = nil
      detailHeaderView?.isHidden = false
    }
  }

  lazy var emptyContentConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .musicalNotes
    config.text = "No Songs"
    config.secondaryText = "Your songs will appear here."
    return config
  }()

  func applyFilter() {
    switch displayFilter {
    case .all:
      filterTitle = "Songs"
      isIndexTitelsHidden = false
      change(sortType: appDelegate.storage.settings.user.songsSortSetting)
    case .newest, .recent:
      break
    case .favorites:
      filterTitle = "Favorite Songs"
      isIndexTitelsHidden = false
      if account.apiType.asServerApiType != .ampache {
        change(sortType: appDelegate.storage.settings.user.favoriteSongSortSetting)
      } else {
        change(sortType: appDelegate.storage.settings.user.songsSortSetting)
      }
    }
    setNavBarTitle(title: filterTitle)
  }

  func change(sortType: SongElementSortType) {
    self.sortType = sortType
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = SongsFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.hasSectionTitles
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController

    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    switch sortType {
    case .rating:
      tableView.sectionHeaderHeight = CommonScreenOperations.tableSectionHeightLarge
      tableView.estimatedSectionHeaderHeight = CommonScreenOperations.tableSectionHeightLarge
    default:
      tableView.sectionHeaderHeight = 0.0
      tableView.estimatedSectionHeaderHeight = 0.0
    }

    tableView.reloadData()
    updateRightBarButtonItems()
    detailHeaderView?.refresh()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    updateRightBarButtonItems()
    updateFromRemote()
    detailHeaderView?.refresh()
  }

  func updateRightBarButtonItems() {
    var actions = [UIMenu]()
    actions.append(createSortButtonMenu())
    if appDelegate.storage.settings.user.isOnlineMode {
      actions.append(createActionButtonMenu())
    }
    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = UIMenu(children: actions)
    navigationItem.rightBarButtonItems = [optionsButton]
  }

  func updateFromRemote() {
    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    switch displayFilter {
    case .all:
      break
    case .newest, .recent:
      break
    case .favorites:
      Task { @MainActor in
        do {
          try await self.appDelegate.getMeta(self.account.info).librarySyncer
            .syncFavoriteLibraryElements()
        } catch {
          self.appDelegate.eventLogger.report(topic: "Favorite Songs Sync", error: error)
        }
        self.detailHeaderView?.refresh()
        self.updateSearchResults(for: self.searchController)
      }
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    let song = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
    return cell
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    switch sortType {
    case .name:
      return 0.0
    case .rating:
      return CommonScreenOperations.tableSectionHeightLarge
    case .addedDate:
      return 0.0
    case .duration:
      return 0.0
    case .starredDate:
      return 0.0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    switch sortType {
    case .name:
      return super.tableView(tableView, titleForHeaderInSection: section)
    case .rating:
      if let sectionNameInitial = super.tableView(tableView, titleForHeaderInSection: section),
         sectionNameInitial != SectionIndexType.noRatingIndexSymbol {
        return "\(sectionNameInitial) Star\(sectionNameInitial != "1" ? "s" : "")"
      } else {
        return "Not rated"
      }
    case .addedDate:
      return nil
    case .duration:
      return nil
    case .starredDate:
      return nil
    }
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext {
    let song = fetchedResultsController.getWrappedEntity(at: songIndexPath)

    guard let allFetchedObjects = fetchedResultsController.fetchedObjects,
          let arrayIndex = allFetchedObjects.firstIndex(of: song.managedObject)
    else { return PlayContext(containable: song) }

    var contextPlayables = [AbstractPlayable]()
    let endIndex = min(arrayIndex + Self.maxPlayContextCount - 1, allFetchedObjects.count - 1)
    for i in arrayIndex ... endIndex {
      contextPlayables.append(Song(managedObject: allFetchedObjects[i]))
    }
    return PlayContext(name: filterTitle, playables: contextPlayables)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell) else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: indexPath)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    guard let searchText = searchController.searchBar.text else { return }
    if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 0 {
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer
          .searchSongs(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Songs Search", error: error)
      }}
      fetchedResultsController.search(
        searchText: searchText,
        onlyCachedSongs: false,
        displayFilter: displayFilter
      )
    } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
      fetchedResultsController.search(
        searchText: searchText,
        onlyCachedSongs: true,
        displayFilter: displayFilter
      )
    } else if displayFilter != .all {
      fetchedResultsController.search(
        searchText: searchText,
        onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1,
        displayFilter: displayFilter
      )
    } else {
      fetchedResultsController.showAllResults()
    }
    tableView.reloadData()
    detailHeaderView?.refresh()
    updateContentUnavailable()
  }

  private func saveSortPreference(preference: SongElementSortType) {
    if account.apiType.asServerApiType != .ampache, displayFilter == .favorites {
      appDelegate.storage.settings.user.favoriteSongSortSetting = preference
    } else {
      appDelegate.storage.settings.user.songsSortSetting = preference
    }
  }

  private func handleHeaderPlay() -> PlayContext {
    guard let displayedSongsMO = fetchedResultsController.fetchedObjects else { return PlayContext(
      name: filterTitle,
      playables: []
    ) }
    if displayedSongsMO.count > appDelegate.player.maxSongsToAddOnce {
      let songsToPlay = displayedSongsMO.prefix(appDelegate.player.maxSongsToAddOnce)
        .compactMap { Song(managedObject: $0) }
      return PlayContext(name: filterTitle, playables: songsToPlay)
    } else {
      let songsToPlay = displayedSongsMO.compactMap { Song(managedObject: $0) }
      return PlayContext(name: filterTitle, playables: songsToPlay)
    }
  }

  private func handleHeaderShuffle() -> PlayContext {
    guard let displayedSongsMO = fetchedResultsController.fetchedObjects else { return PlayContext(
      name: filterTitle,
      playables: []
    ) }
    if displayedSongsMO.count > appDelegate.player.maxSongsToAddOnce {
      let songsToPlay = displayedSongsMO[randomPick: appDelegate.player.maxSongsToAddOnce]
        .compactMap { Song(managedObject: $0) }
      return PlayContext(name: filterTitle, playables: songsToPlay)
    } else {
      let songsToPlay = displayedSongsMO.compactMap { Song(managedObject: $0) }
      return PlayContext(name: filterTitle, playables: songsToPlay)
    }
  }

  private func createSortButtonMenu() -> UIMenu {
    let sortByName = UIAction(
      title: "Name",
      image: sortType == .name ? .check : nil,
      handler: { _ in
        self.change(sortType: .name)
        self.saveSortPreference(preference: .name)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByRating = UIAction(
      title: "Rating",
      image: sortType == .rating ? .check : nil,
      handler: { _ in
        self.change(sortType: .rating)
        self.saveSortPreference(preference: .rating)
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
        self.saveSortPreference(preference: .duration)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByStarredDate = UIAction(
      title: "Starred date",
      image: sortType == .starredDate ? .check : nil,
      handler: { _ in
        self.change(sortType: .starredDate)
        self.saveSortPreference(preference: .starredDate)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByAddedDate = UIAction(
      title: "Date Added",
      image: sortType == .addedDate ? .check : nil,
      handler: { _ in
        self.change(sortType: .addedDate)
        self.saveSortPreference(preference: .addedDate)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    if displayFilter == .favorites, account.apiType.asServerApiType != .ampache {
      return UIMenu(
        title: "Sort",
        image: .sort,
        options: [],
        children: [sortByName, sortByRating, sortByDuration, sortByStarredDate, sortByAddedDate]
      )
    } else if account.apiType.asServerApiType != .ampache {
      return UIMenu(
        title: "Sort",
        image: .sort,
        options: [],
        children: [sortByName, sortByRating, sortByDuration, sortByAddedDate]
      )
    } else {
      return UIMenu(
        title: "Sort",
        image: .sort,
        options: [],
        children: [sortByName, sortByRating, sortByDuration]
      )
    }
  }

  private func createActionButtonMenu() -> UIMenu {
    let action = UIAction(
      title: "Download \(filterTitle)",
      image: UIImage.startDownload,
      handler: { _ in
        var songs = [Song]()
        switch self.displayFilter {
        case .all:
          songs = self.appDelegate.storage.main.library.getSongs(for: self.account)
        case .newest, .recent:
          break
        case .favorites:
          songs = self.appDelegate.storage.main.library
            .getFavoriteSongs(for: self.account)
        }
        if songs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
          let alert = UIAlertController(
            title: "Many Songs",
            message: "Are you sure to add \(songs.count) songs from \"\(self.filterTitle)\" to download queue?",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.appDelegate.getMeta(self.account.info).playableDownloadManager
              .download(objects: songs)
          }))
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          self.present(alert, animated: true, completion: nil)
        } else {
          self.appDelegate.getMeta(self.account.info).playableDownloadManager
            .download(objects: songs)
        }
      }
    )
    return UIMenu(options: [.displayInline], children: [action])
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    guard appDelegate.storage.settings.user.isOnlineMode else {
      self.refreshControl?.endRefreshing()
      return
    }
    Task { @MainActor in
      do {
        try await AutoDownloadLibrarySyncer(
          storage: self.appDelegate.storage,
          account: self.account,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
            .playableDownloadManager
        )
        .syncNewestLibraryElements()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Songs Newest Elements Sync", error: error)
      }
      detailHeaderView?.refresh()
      self.refreshControl?.endRefreshing()
    }
  }
}
