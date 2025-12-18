//
//  PlaylistAddGenresVC.swift
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

class PlaylistAddGenresVC: SingleFetchedResultsTableViewController<GenreMO>, PlaylistVCAddable {
  override var sceneTitle: String? { "Genres" }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: GenreFetchedResultsController!
  private var doneButton: UIBarButtonItem!

  init(account: Account) {
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    fetchedResultsController = GenreFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      isGroupedInAlphabeticSections: true
    )
    singleFetchedResultsController = fetchedResultsController

    configureSearchController(
      placeholder: "Search in \"Genres\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    setNavBarTitle(title: "Genres")
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.rowHeight = GenericTableCell.rowHeightWithoutImage
    tableView.estimatedRowHeight = GenericTableCell.rowHeightWithoutImage
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
    let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(
      container: genre,
      rootView: self
    )
    cell.entityImage.isHidden = true
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
    let nextVC = PlaylistAddGenreDetailVC(account: account, genre: genre)
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(
      searchText: searchText,
      onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1
    )
    tableView.reloadData()
  }
}
