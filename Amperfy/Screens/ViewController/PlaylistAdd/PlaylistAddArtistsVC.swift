//
//  PlaylistAddArtistsVC.swift
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

class PlaylistAddArtistsVC: SingleSnapshotFetchedResultsTableViewController<ArtistMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? {
    switch displayFilter {
    case .albumArtists, .all: "Artists"
    case .favorites: "Favorite Artists"
    }
  }

  public var displayFilter: ArtistCategoryFilter = .all
  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: ArtistFetchedResultsController!
  private var sortType: ArtistElementSortType = .name
  private var doneButton: UIBarButtonItem!

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
    return source
  }

  func artistAt(indexPath: IndexPath) -> Artist? {
    (diffableDataSource as? ArtistDiffableDataSource)?.artistAt(indexPath: indexPath)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    change(sortType: appDelegate.storage.settings.user.artistsSortSetting)
    change(filterType: appDelegate.storage.settings.user.artistsFilterSetting)
    configureSearchController(
      placeholder: "Search in \"\(sceneTitle ?? "Artists")\"",
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
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  func change(sortType: ArtistElementSortType) {
    self.sortType = sortType
    // changes are not going to be saved
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
  }

  func change(filterType: ArtistCategoryFilter) {
    // favorite views can't change the display filter
    guard displayFilter != .favorites else { return }
    displayFilter = filterType
    appDelegate.storage.settings.user.artistsFilterSetting = filterType
    updateSearchResults(for: searchController)
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

    let nextVC = PlaylistAddArtistDetailVC(account: account, artist: artist)
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
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
        try await self.appDelegate.getMeta(account.info).librarySyncer
          .searchArtists(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
      }}
    }
  }
}
