//
//  PlaylistSelectorVC.swift
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

// MARK: - AddToPlaylistSelectMode

enum AddToPlaylistSelectMode {
  case single
  case multi
}

// MARK: - PlaylistsSelectorDiffableDataSource

class PlaylistsSelectorDiffableDataSource: BasicUITableViewDiffableDataSource {
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    false
  }
}

// MARK: - PlaylistSelectorVC

class PlaylistSelectorVC: SingleSnapshotFetchedResultsTableViewController<PlaylistMO> {
  override var sceneTitle: String? { "Playlists" }

  let itemsToAdd: [Song]
  private var selectedPlaylits = [Playlist: [Song]]()

  private var fetchedResultsController: PlaylistSelectorFetchedResultsController!
  private var sortType: PlaylistSortType = .name
  private var selectMode = AddToPlaylistSelectMode.single
  private var optionsButton: UIBarButtonItem!
  private var closeButton: UIBarButtonItem!
  private var selectBarButton: UIBarButtonItem!
  private var addBarButton: UIBarButtonItem!

  init(account: Account, itemsToAdd: [Song]) {
    self.itemsToAdd = itemsToAdd
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      PlaylistsSelectorDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistMO = object as? PlaylistMO
        else {
          return UITableViewCell()
        }
        let playlist = Playlist(
          library: self.appDelegate.storage.main.library,
          managedObject: playlistMO
        )
        return self.createCell(tableView, forRowAt: indexPath, playlist: playlist)
      }
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    optionsButton = UIBarButtonItem.createSortBarButton()

    appDelegate.userStatistics.visited(.playlistSelector)
    setNavBarTitle(
      title: ((itemsToAdd.count) > 1) ?
        "Add \(itemsToAdd.count) Songs to Playlist" : "Add to Playlist"
    )

    change(sortType: appDelegate.storage.settings.user.playlistsSortSetting)

    configureSearchController(placeholder: "Search in \"Playlists\"")
    tableView.register(nibName: PlaylistTableCell.typeName)
    tableView.rowHeight = PlaylistTableCell.rowHeight
    tableView.estimatedRowHeight = PlaylistTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    tableView.tableHeaderView = UIView(frame: CGRect(
      x: 0,
      y: 0,
      width: view.bounds.size.width,
      height: NewPlaylistTableHeader.frameHeight
    ))
    if let newPlaylistTableHeaderView = ViewCreator<NewPlaylistTableHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: NewPlaylistTableHeader.frameHeight
      )) {
      tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
      newPlaylistTableHeaderView.account = account
    }

    navigationController?.setToolbarHidden(false, animated: false)
    let flexible = UIBarButtonItem(
      barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
      target: self,
      action: nil
    )
    selectBarButton = UIBarButtonItem(
      title: "Select",
      style: .plain,
      target: self,
      action: #selector(selectBarButtonPressed)
    )
    addBarButton = UIBarButtonItem(
      image: .plus,
      style: .plain,
      target: self,
      action: #selector(addBarButtonPressed)
    )
    toolbarItems = [selectBarButton, flexible, addBarButton]
    refreshAddButton()
  }

  func change(sortType: PlaylistSortType) {
    self.sortType = sortType
    // sortType will not be saved permanently. This behaviour differs from PlaylistsVC
    singleFetchedResultsController?.clearResults()
    tableView.reloadData()
    fetchedResultsController = PlaylistSelectorFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: account,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType != .none
    )
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()
    tableView.reloadData()
    updateRightBarButtonItems()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateRightBarButtonItems()
    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await self.appDelegate.getMeta(self.account.info).librarySyncer
        .syncDownPlaylistsWithoutSongs()
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
    }}
  }

  func updateRightBarButtonItems() {
    closeButton = UIBarButtonItem.createCloseBarButton(
      target: self,
      selector: #selector(cancelBarButtonPressed)
    )
    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = createSortButtonMenu()
    navigationItem.rightBarButtonItems = [closeButton, optionsButton]
  }

  @IBAction
  func addBarButtonPressed(_ sender: UIBarButtonItem) {
    addSongsToSelectedPlaylists()
    refreshAddButton()
    dismiss()
  }

  func addSongsToSelectedPlaylists() {
    defer { selectedPlaylits.removeAll() }
    guard !selectedPlaylits.isEmpty else { return }

    let localCopySelectedPlaylits = selectedPlaylits
    Task { @MainActor in do {
      for (playlist, songs) in localCopySelectedPlaylits {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer.syncUpload(
          playlistToAddSongs: playlist,
          songs: songs
        )
        playlist.append(playables: songs)
      }
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlist Add Songs", error: error)
    }}
  }

  @IBAction
  func selectBarButtonPressed(_ sender: Any) {
    selectMode = ((selectMode == .single) ? .multi : .single)
    selectBarButton.isSelected = (selectMode == .multi)
    refreshAddButton()
    selectedPlaylits.removeAll()
    tableView.reloadData()
  }

  func refreshAddButton() {
    addBarButton.isEnabled = !selectedPlaylits.isEmpty
  }

  @IBAction
  func cancelBarButtonPressed(_ sender: UIBarButtonItem) {
    dismiss()
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
    let sortByLastTimePlayed = UIAction(
      title: "Last time played",
      image: sortType == .lastPlayed ? .check : nil,
      handler: { _ in
        self.change(sortType: .lastPlayed)
        self.updateSearchResults(for: self.searchController)
        self.appDelegate.notificationHandler.post(
          name: .fetchControllerSortChanged,
          object: nil,
          userInfo: nil
        )
      }
    )
    let sortByChangeDate = UIAction(
      title: "Change date",
      image: sortType == .lastChanged ? .check : nil,
      handler: { _ in
        self.change(sortType: .lastChanged)
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
      children: [sortByName, sortByLastTimePlayed, sortByChangeDate, sortByDuration]
    )
  }

  private func dismiss() {
    searchController.dismiss(animated: false, completion: nil)
    dismiss(animated: true, completion: nil)
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    playlist: Playlist
  )
    -> UITableViewCell {
    let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
    cell.display(playlist: playlist, rootView: nil)

    if selectMode == .multi {
      let isMarked = (selectedPlaylits[playlist] != nil)
      let img = UIImageView(image: isMarked ? .checkmark : .circle)
      img.tintColor = isMarked ? appDelegate.storage.settings.accounts
        .getSetting(playlist.account?.info).read
        .themePreference
        .asColor : .secondaryLabelColor
      cell.accessoryView = img
    } else {
      cell.accessoryView = nil
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    guard let diffableDataSource else { return }
    let objectID = diffableDataSource.itemIdentifier(for: indexPath)
    guard let objectID,
          let object = try? appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistMO = object as? PlaylistMO
    else {
      return
    }

    let playlist = Playlist(
      library: appDelegate.storage.main.library,
      managedObject: playlistMO
    )

    func handleSuccessfullSelection(playables: [AbstractPlayable]) {
      let songs = playables.filterSongs()
      if !songs.isEmpty {
        selectedPlaylits[playlist] = songs
      } else {
        selectedPlaylits.removeValue(forKey: playlist)
      }

      var snap = diffableDataSource.snapshot()
      snap.reconfigureItems([playlist.managedObject.objectID])
      diffableDataSource.apply(snap)

      if selectMode == .single {
        addSongsToSelectedPlaylists()
        dismiss()
      } else {
        refreshAddButton()
      }
    }

    if selectedPlaylits[playlist] != nil {
      selectedPlaylits.removeValue(forKey: playlist)
      var snap = diffableDataSource.snapshot()
      snap.reconfigureItems([playlist.managedObject.objectID])
      diffableDataSource.apply(snap)
    } else {
      let itemsNotContained = playlist.notContaines(playables: itemsToAdd)
      if itemsNotContained.count != itemsToAdd.count {
        let alert = UIAlertController(
          title: nil,
          message: "Some Songs are already in this Playlist.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Add Duplicates", style: .default, handler: { _ in
          handleSuccessfullSelection(playables: self.itemsToAdd)
        }))
        alert.addAction(UIAlertAction(title: "Skip Duplicates", style: .default, handler: { _ in
          handleSuccessfullSelection(playables: Array(itemsNotContained))
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
          // do nothing
        }))
        present(alert, animated: true, completion: nil)
      } else {
        handleSuccessfullSelection(playables: itemsToAdd)
      }
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    fetchedResultsController.search(searchText: searchText)
    tableView.reloadData()
  }
}
