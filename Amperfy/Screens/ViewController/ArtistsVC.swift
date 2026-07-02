//
//  ArtistsVC.swift
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

// MARK: - ArtistDiffableDataSource

class ArtistDiffableDataSource: BasicUITableViewDiffableDataSource {
  var sortType: ArtistElementSortType = .name

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    false
  }

  func artistAt(indexPath: IndexPath) -> Artist? {
    let objectID = itemIdentifier(for: indexPath)
    guard let objectID,
          let object = try? appDelegate.storage.main.context
          .existingObject(with: objectID),
          let artistMO = object as? ArtistMO
    else {
      return nil
    }
    return Artist(managedObject: artistMO)
  }

  func getFirstArtist(in section: Int) -> Artist? {
    artistAt(indexPath: IndexPath(row: 0, section: section))
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    guard let artist = getFirstArtist(in: section) else { return nil }
    switch sortType {
    case .name:
      return artist.name.prefix(1).uppercased()
    case .rating:
      if artist.rating > 0 {
        return "\(artist.rating) Star\(artist.rating != 1 ? "s" : "")"
      } else {
        return "Not rated"
      }
    case .duration:
      return artist.duration.description
    case .newest:
      return nil
    }
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    let sectionCount = numberOfSections(in: tableView)
    var indexTitles = [String]()
    for i in 0 ..< sectionCount {
      if let sectionName = self.tableView(tableView, titleForHeaderInSection: i) {
        var indexTitle = ""
        switch sortType {
        case .name:
          indexTitle = sectionName.prefix(1).uppercased()
          if let _ = Int(indexTitle) {
            indexTitle = "#"
          }
        case .rating:
          indexTitle = IndexHeaderNameGenerator.sortByRating(forSectionName: sectionName)
        case .duration:
          indexTitle = IndexHeaderNameGenerator.sortByDurationArtist(forSectionName: sectionName)
        case .newest:
          break
        }
        indexTitles.append(indexTitle)
      }
    }
    return indexTitles.isEmpty ? nil : indexTitles
  }

  override func tableView(
    _ tableView: UITableView,
    sectionForSectionIndexTitle title: String,
    at index: Int
  )
    -> Int {
    index
  }
}

// MARK: - ArtistsVC

class ArtistsVC: SingleSnapshotFetchedResultsTableViewController<ArtistMO> {
  override var sceneTitle: String? {
    switch displayFilter {
    case .albumArtists, .all: "Artists"
    case .favorites: "Favorite Artists"
    }
  }

  private var fetchedResultsController: ArtistFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  public var displayFilter: ArtistCategoryFilter = .all
  private var sortType: ArtistElementSortType = .name
  private var filterTitle = "Artists"

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      ArtistDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let artistMO = object as? ArtistMO
        else {
          return UITableViewCell()
        }
        let artist = Artist(
          managedObject: artistMO
        )
        return self.createCell(tableView, forRowAt: indexPath, artist: artist)
      }
    source.sortType = sortType
    return source
  }

  func artistAt(indexPath: IndexPath) -> Artist? {
    (diffableDataSource as? ArtistDiffableDataSource)?.artistAt(indexPath: indexPath)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.artists)

    optionsButton = UIBarButtonItem.createOptionsBarButton()

    applyFilter()
    change(sortType: appDelegate.storage.settings.user.artistsSortSetting)
    change(filterType: appDelegate.storage.settings.user.artistsFilterSetting)
    configureSearchController(
      placeholder: "Search in \"\(filterTitle)\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.rowHeight = GenericTableCell.rowHeight
    tableView.estimatedRowHeight = GenericTableCell.rowHeight
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    containableAtIndexPathCallback = { indexPath in
      self.artistAt(indexPath: indexPath)
    }
    playContextAtIndexPathCallback = { indexPath in
      let entity = self.artistAt(indexPath: indexPath)
      guard let entity else { return nil }
      return PlayContext(containable: entity)
    }
    swipeCallback = { indexPath, completionHandler in
      let artist = self.artistAt(indexPath: indexPath)
      guard let artist else { return }
      Task { @MainActor in
        do {
          try await artist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
            playableDownloadManager: self.appDelegate.getMeta(self.account.info)
              .playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: artist))
      }
    }
    snapshotDidChange = {
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
    } else {
      contentUnavailableConfiguration = nil
    }
  }

  lazy var emptyContentConfig: UIContentUnavailableConfiguration = {
    var config = UIContentUnavailableConfiguration.empty()
    config.image = .artist
    config.text = "No " + filterTitle
    config.secondaryText = "Your " + filterTitle.lowercased() + " will appear here."
    return config
  }()

  func applyFilter() {
    switch displayFilter {
    case .all:
      filterTitle = "Artists"
    case .favorites:
      filterTitle = "Favorite Artists"
    case .albumArtists:
      filterTitle = "Album Artists"
    }
    setNavBarTitle(title: filterTitle)
  }

  func change(sortType: ArtistElementSortType) {
    self.sortType = sortType
    appDelegate.storage.settings.user.artistsSortSetting = sortType
    (diffableDataSource as? ArtistDiffableDataSource)?.sortType = sortType
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      sortType: sortType,
      isGroupedInAlphabeticSections: true
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()
    tableView.reloadData()
    updateRightBarButtonItems()
  }

  func change(filterType: ArtistCategoryFilter) {
    // favorite views can't change the display filter
    guard displayFilter != .favorites else { return }
    displayFilter = filterType
    appDelegate.storage.settings.user.artistsFilterSetting = filterType
    updateSearchResults(for: searchController)
    updateRightBarButtonItems()
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
    updateContentUnavailable()
  }

  func updateRightBarButtonItems() {
    var actions = [UIMenu]()
    actions.append(createSortButtonMenu())
    if displayFilter != .favorites {
      actions.append(createFilterButtonMenu())
    }
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
    case .albumArtists, .all:
      break
    case .favorites:
      Task { @MainActor in
        do {
          try await self.appDelegate.getMeta(self.account.info).librarySyncer
            .syncFavoriteLibraryElements()
        } catch {
          self.appDelegate.eventLogger.report(topic: "Favorite Artists Sync", error: error)
        }
        self.updateSearchResults(for: self.searchController)
      }
    }
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    artist: Artist
  )
    -> UITableViewCell {
    let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
    cell.display(container: artist, rootView: self)
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
    case .newest:
      return 0.0
    case .duration:
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
    case .newest:
      return super.tableView(tableView, titleForHeaderInSection: section)
    case .duration:
      return nil
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let artist = artistAt(indexPath: indexPath) else { return }
    navigationController?.pushViewController(
      AppStoryboard.Main.segueToArtistDetail(account: account, artist: artist),
      animated: true
    )
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(
      searchText: searchText,
      onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1,
      displayFilter: displayFilter
    )
    tableView.reloadData()
    if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 0 {
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer
          .searchArtists(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
      }}
    }
    updateContentUnavailable()
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
    let sortByRating = UIAction(
      title: "Rating",
      image: sortType == .rating ? .check : nil,
      handler: { _ in
        self.change(sortType: .rating)
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
      options: [],
      children: [sortByName, sortByRating, sortByDuration]
    )
  }

  private func createFilterButtonMenu() -> UIMenu {
    let filterAll = UIAction(
      title: "All",
      image: displayFilter == .all ? .check : nil,
      handler: { _ in
        self.change(filterType: .all)
      }
    )
    let filterAlbumArtists = UIAction(
      title: "Album Artists",
      image: displayFilter == .albumArtists ? .check : nil,
      handler: { _ in
        self.change(filterType: .albumArtists)
      }
    )
    return UIMenu(
      title: "Filter",
      image: .filter,
      options: [],
      children: [filterAll, filterAlbumArtists]
    )
  }

  private func createActionButtonMenu() -> UIMenu {
    let action = UIAction(
      title: "Download \(filterTitle)",
      image: UIImage.startDownload,
      handler: { _ in
        var artists = [Artist]()
        switch self.displayFilter {
        case .all:
          artists = self.appDelegate.storage.main.library.getArtists(for: self.account)
        case .albumArtists:
          artists = self.appDelegate.storage.main.library
            .getAlbumArtists(for: self.account)
        case .favorites:
          artists = self.appDelegate.storage.main.library
            .getFavoriteArtists(for: self.account)
        }
        let artistSongs = Array(artists.compactMap { $0.playables }.joined())
        if artistSongs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
          let alert = UIAlertController(
            title: "Many Songs",
            message: "Are you sure to add \(artistSongs.count) songs from \"\(self.filterTitle)\" to download queue?",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.appDelegate.getMeta(self.account.info).playableDownloadManager
              .download(objects: artistSongs)
          }))
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          self.present(alert, animated: true, completion: nil)
        } else {
          self.appDelegate.getMeta(self.account.info).playableDownloadManager
            .download(objects: artistSongs)
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
          account: account,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
            .playableDownloadManager
        )
        .syncNewestLibraryElements()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artists Newest Elements Sync", error: error)
      }
      self.refreshControl?.endRefreshing()
    }
  }
}
