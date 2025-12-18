//
//  PlaylistAddDirectoriesVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.12.24.
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

class PlaylistAddDirectoriesVC: MultiSourceTableViewController, PlaylistVCAddable {
  override var sceneTitle: String? { directory.name }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var subdirectoriesFetchedResultsController: DirectorySubdirectoriesFetchedResultsController!
  private var songsFetchedResultsController: DirectorySongsFetchedResultsController!
  private var doneButton: UIBarButtonItem!
  private let directory: Directory

  init(account: Account, directory: Directory) {
    self.directory = directory
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

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
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()
    subdirectoriesFetchedResultsController?.delegate = self
    songsFetchedResultsController?.delegate = self
    addToPlaylistManager.configuteToolbar(
      viewVC: self,
      selectButtonSelector: #selector(selectAllButtonPressed)
    )

    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.getMeta(account.info).librarySyncer
        .sync(directory: directory)
    } catch {
      self.appDelegate.eventLogger.report(topic: "Directories Sync", error: error)
    }}
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    subdirectoriesFetchedResultsController?.delegate = nil
    songsFetchedResultsController?.delegate = nil
    addToPlaylistManager.hideToolbar(viewVC: self)
  }

  @IBAction
  func selectAllButtonPressed(_ sender: UIBarButtonItem) {
    if let songs = songsFetchedResultsController?.fetchedObjects?
      .compactMap({ Song(managedObject: $0) }) {
      addToPlaylistManager.toggleSelection(playables: songs, rootVC: self, doneCB: {
        self.tableView.reloadData()
        self.updateTitle()
      })
    }
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
      cell.display(
        playable: song,
        displayMode: .add,
        playContextCb: nil,
        rootView: self,
        isMarked: addToPlaylistManager.contains(playable: song)
      )
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

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch indexPath.section {
    case 0:
      let selectedDirectory = subdirectoriesFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      let nextVC = PlaylistAddDirectoriesVC(account: account, directory: selectedDirectory)
      nextVC.addToPlaylistManager = addToPlaylistManager
      navigationController?.pushViewController(nextVC, animated: true)
    case 1:
      let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      if let cell = tableView.cellForRow(at: indexPath) as? PlayableTableCell {
        addToPlaylistManager.toggleSelection(playable: song, rootVC: self) {
          cell.isMarked = $0
          cell.refresh()
          self.updateTitle()
        }
      }
    default: break
    }
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
