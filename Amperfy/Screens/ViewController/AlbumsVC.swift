//
//  AlbumsVC.swift
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

// MARK: - AlbumsDiffableDataSource

class AlbumsDiffableDataSource: BasicUITableViewDiffableDataSource {
  var sortType: AlbumElementSortType = .name

  func getAlbum(at indexPath: IndexPath) -> Album? {
    guard let objectID = itemIdentifier(for: indexPath) else { return nil }
    guard let object = try? appDelegate.storage.main.context.existingObject(with: objectID),
          let albumMO = object as? AlbumMO
    else {
      return nil
    }
    return Album(managedObject: albumMO)
  }

  func getFirstAlbum(in section: Int) -> Album? {
    getAlbum(at: IndexPath(row: 0, section: section))
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    switch sortType {
    case .name:
      guard let album = getFirstAlbum(in: section) else { return nil }
      return album.name
    case .rating:
      guard let album = getFirstAlbum(in: section) else { return nil }
      if album.rating > 0 {
        return "\(album.rating) Star\(album.rating != 1 ? "s" : "")"
      } else {
        return "Not rated"
      }
    case .newest, .recent:
      return nil
    case .artist:
      guard let album = getFirstAlbum(in: section) else { return nil }
      return album.subtitle
    case .duration:
      guard let album = getFirstAlbum(in: section) else { return nil }
      return album.duration.description
    case .year:
      let year = getFirstAlbum(in: section)?.year.description
      guard let year = year else { return nil }
      return IndexHeaderNameGenerator.sortByYear(forSectionName: year)
    }
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    let sectionCount = numberOfSections(in: tableView)
    var indexTitles = [String]()
    for i in 0 ... sectionCount {
      if let sectionName = self.tableView(tableView, titleForHeaderInSection: i) {
        var indexTitle = ""
        switch sortType {
        case .name:
          indexTitle = sectionName.prefix(1).uppercased()
          if let _ = Int(indexTitle) {
            indexTitle = "#"
          }
        case .artist:
          indexTitle = sectionName.prefix(1).uppercased()
          if let _ = Int(indexTitle) {
            indexTitle = "#"
          }
        case .rating:
          indexTitle = IndexHeaderNameGenerator.sortByRating(forSectionName: sectionName)
        case .duration:
          indexTitle = IndexHeaderNameGenerator.sortByDurationAlbum(forSectionName: sectionName)
        case .year:
          indexTitle = IndexHeaderNameGenerator.sortByYear(forSectionName: sectionName)
        default:
          break
        }
        indexTitles.append(indexTitle)
      }
    }
    return indexTitles
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

// MARK: - AlbumsVC

class AlbumsVC: SingleSnapshotFetchedResultsTableViewController<AlbumMO> {
  override var sceneTitle: String? {
    common.sceneTitle
  }

  private let common: AlbumsCommonVCInteractions
  private var detailHeader: LibraryElementDetailTableHeaderView?

  public var displayFilter: DisplayCategoryFilter {
    set { common.displayFilter = newValue }
    get { common.displayFilter }
  }

  private var albumsDataSource: AlbumsDiffableDataSource? {
    diffableDataSource as? AlbumsDiffableDataSource
  }

  init(account: Account) {
    self.common = AlbumsCommonVCInteractions(account: account)
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      AlbumsDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let albumMO = object as? AlbumMO
        else {
          fatalError("Managed object should be available")
        }
        let album = Album(managedObject: albumMO)
        return self.createCell(tableView, forRowAt: indexPath, album: album)
      }
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    appDelegate.userStatistics.visited(.albums)

    common.rootVC = self
    common.isIndexTitelsHiddenCB = {
      self.isIndexTitelsHidden = self.common.isIndexTitelsHidden
    }
    common.reloadListViewCB = {
      self.tableView.reloadData()
    }
    common.updateSearchResultsCB = {
      self.updateSearchResults(for: self.searchController)
    }
    common.endRefreshCB = {
      self.refreshControl?.endRefreshing()
    }
    common.updateFetchDataSourceCB = {
      (self.diffableDataSource as? AlbumsDiffableDataSource)?.sortType = self.common.sortType
      self.singleFetchedResultsController = self.common.fetchedResultsController
      self.singleFetchedResultsController?.delegate = self
    }

    common.applyFilter()
    configureSearchController(
      placeholder: "Search in \"\(common.filterTitle)\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.rowHeight = GenericTableCell.rowHeight
    tableView.estimatedRowHeight = GenericTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    detailHeader = LibraryElementDetailTableHeaderView.createTableHeader(
      rootView: self,
      configuration: common.createPlayShuffleInfoConfig()
    )
    refreshControl?.addTarget(
      common,
      action: #selector(AlbumsCommonVCInteractions.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    containableAtIndexPathCallback = { indexPath in
      self.albumsDataSource?.getAlbum(at: indexPath)
    }
    playContextAtIndexPathCallback = { indexPath in
      guard let album = self.albumsDataSource?.getAlbum(at: indexPath) else { return nil }
      return PlayContext(containable: album)
    }
    swipeCallback = { indexPath, completionHandler in
      guard let album = self.albumsDataSource?.getAlbum(at: indexPath) else {
        completionHandler(nil)
        return
      }
      Task { @MainActor in
        do {
          try await album.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
            playableDownloadManager: self.appDelegate.getMeta(self.account.info)
              .playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: album))
      }
    }
    snapshotDidChange = {
      self.common.updateContentUnavailable()
      self.updateHeaderViewVisibility()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    detailHeader?.refresh()
    common.updateRightBarButtonItems()
    common.updateFromRemote()
    common.updateContentUnavailable()
    updateHeaderViewVisibility()
  }

  func updateHeaderViewVisibility() {
    detailHeader?.isHidden = common.isContentUnavailable
  }

  override func tableView(
    _ tableView: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
  ) {
    common.listViewWillDisplayCell(at: indexPath, searchBarText: searchController.searchBar.text)
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    album: Album
  )
    -> UITableViewCell {
    let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
    if let album = (diffableDataSource as? AlbumsDiffableDataSource)?.getAlbum(at: indexPath) {
      cell.display(container: album, rootView: self)
    }
    return cell
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    switch common.sortType {
    case .artist, .duration, .name, .newest, .recent:
      return 0.0
    case .rating, .year:
      return CommonScreenOperations.tableSectionHeightLarge
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let album = (diffableDataSource as? AlbumsDiffableDataSource)?.getAlbum(at: indexPath)
    else { return }
    navigationController?.pushViewController(
      AppStoryboard.Main.segueToAlbumDetail(account: account, album: album),
      animated: true
    )
  }

  override func updateSearchResults(for searchController: UISearchController) {
    common.updateSearchResults(for: self.searchController)
    tableView.reloadData()
    detailHeader?.refresh()
    updateHeaderViewVisibility()
  }
}
