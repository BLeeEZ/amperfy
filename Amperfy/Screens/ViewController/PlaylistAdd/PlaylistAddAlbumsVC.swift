//
//  PlaylistAddAlbumsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.12.24.
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

class PlaylistAddAlbumsVC: SingleSnapshotFetchedResultsTableViewController<AlbumMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? {
    common.sceneTitle
  }

  private var common: AlbumsCommonVCInteractions
  private var doneButton: UIBarButtonItem!

  public var addToPlaylistManager = AddToPlaylistManager()

  public var displayFilter: DisplayCategoryFilter {
    set { common.displayFilter = newValue }
    get { common.displayFilter }
  }

  private var albumsDataSource: AlbumsDiffableDataSource? {
    diffableDataSource as? AlbumsDiffableDataSource
  }

  init(account: Account) {
    self.common = AlbumsCommonVCInteractions(account: account, isSetNavbarButton: false)
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

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

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
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()

    common.updateFromRemote()
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
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
    tableView.deselectRow(at: indexPath, animated: false)
    guard let album = (diffableDataSource as? AlbumsDiffableDataSource)?.getAlbum(at: indexPath)
    else { return }

    let nextVC = PlaylistAddAlbumDetailVC(account: account, album: album)
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    common.updateSearchResults(for: self.searchController)
    tableView.reloadData()
  }
}
