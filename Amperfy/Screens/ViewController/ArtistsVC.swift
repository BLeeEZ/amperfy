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

class ArtistsVC: SingleFetchedResultsTableViewController<ArtistMO> {
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

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.userStatistics.visited(.artists)

    optionsButton = OptionsBarButton()

    applyFilter()
    change(sortType: appDelegate.storage.settings.artistsSortSetting)
    change(filterType: appDelegate.storage.settings.artistsFilterSetting)
    configureSearchController(
      placeholder: "Search in \"\(filterTitle)\"",
      scopeButtonTitles: ["All", "Cached"],
      showSearchBarAtEnter: true
    )
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.rowHeight = GenericTableCell.rowHeight
    tableView.estimatedRowHeight = GenericTableCell.rowHeight

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
      let artist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      Task { @MainActor in
        do {
          try await artist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: artist))
      }
    }
  }

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
    appDelegate.storage.settings.artistsSortSetting = sortType
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: sortType,
      isGroupedInAlphabeticSections: true
    )
    fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
    singleFetchedResultsController = fetchedResultsController
    tableView.reloadData()
    updateRightBarButtonItems()
  }

  func change(filterType: ArtistCategoryFilter) {
    // favorite views can't change the display filter
    guard displayFilter != .favorites else { return }
    displayFilter = filterType
    appDelegate.storage.settings.artistsFilterSetting = filterType
    updateSearchResults(for: searchController)
    updateRightBarButtonItems()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateRightBarButtonItems()
    updateFromRemote()
  }

  func updateRightBarButtonItems() {
    var actions = [UIMenu]()
    actions.append(createSortButtonMenu())
    if displayFilter != .favorites {
      actions.append(createFilterButtonMenu())
    }
    if appDelegate.storage.settings.isOnlineMode {
      actions.append(createActionButtonMenu())
    }
    optionsButton.menu = UIMenu(children: actions)
    navigationItem.rightBarButtonItems = [optionsButton]
  }

  func updateFromRemote() {
    guard appDelegate.storage.settings.isOnlineMode else { return }
    switch displayFilter {
    case .albumArtists, .all:
      break
    case .favorites:
      Task { @MainActor in
        do {
          try await self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
        } catch {
          self.appDelegate.eventLogger.report(topic: "Favorite Artists Sync", error: error)
        }
        self.updateSearchResults(for: self.searchController)
      }
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
    let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
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
    let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
    performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == Segues.toArtistDetail.rawValue {
      let vc = segue.destination as! ArtistDetailVC
      let artist = sender as? Artist
      vc.artist = artist
    }
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
        try await self.appDelegate.librarySyncer.searchArtists(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
      }}
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
          artists = self.appDelegate.storage.main.library.getArtists()
        case .albumArtists:
          artists = self.appDelegate.storage.main.library.getAlbumArtists()
        case .favorites:
          artists = self.appDelegate.storage.main.library.getFavoriteArtists()
        }
        let artistSongs = Array(artists.compactMap { $0.playables }.joined())
        if artistSongs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
          let alert = UIAlertController(
            title: "Many Songs",
            message: "Are you sure to add \(artistSongs.count) songs from \"\(self.filterTitle)\" to download queue?",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.appDelegate.playableDownloadManager.download(objects: artistSongs)
          }))
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          self.present(alert, animated: true, completion: nil)
        } else {
          self.appDelegate.playableDownloadManager.download(objects: artistSongs)
        }
      }
    )
    return UIMenu(options: [.displayInline], children: [action])
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
        self.appDelegate.eventLogger.report(topic: "Artists Newest Elements Sync", error: error)
      }
      self.refreshControl?.endRefreshing()
    }
  }
}
