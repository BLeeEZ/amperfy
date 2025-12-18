//
//  PlaylistAddAlbumDetailVC.swift
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
import UIKit

class PlaylistAddAlbumDetailVC: SingleSnapshotFetchedResultsTableViewController<SongMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? { album.name }

  public let album: Album
  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: AlbumSongsFetchedResultsController!
  private var doneButton: UIBarButtonItem!

  init(account: Account, album: Album) {
    self.album = album
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      AlbumDetailDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let songMO = object as? SongMO
        else {
          fatalError("Managed object should be available")
        }
        let song = Song(managedObject: songMO)
        return self.createCell(tableView, forRowAt: indexPath, song: song)
      }
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    fetchedResultsController = AlbumSongsFetchedResultsController(
      forAlbum: album,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()

    configureSearchController(
      placeholder: "Search in \"Album\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()
    addToPlaylistManager.configuteToolbar(
      viewVC: self,
      selectButtonSelector: #selector(selectAllButtonPressed)
    )

    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await album.fetch(
        storage: self.appDelegate.storage,
        librarySyncer: self.appDelegate.getMeta(account.info).librarySyncer,
        playableDownloadManager: self.appDelegate.getMeta(account.info)
          .playableDownloadManager
      )
    } catch {
      self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
    }}
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    addToPlaylistManager.hideToolbar(viewVC: self)
  }

  @IBAction
  func selectAllButtonPressed(_ sender: UIBarButtonItem) {
    if let songs = singleFetchedResultsController?.fetchedObjects?
      .compactMap({ Song(managedObject: $0) }) {
      addToPlaylistManager.toggleSelection(playables: songs, rootVC: self, doneCB: {
        self.tableView.reloadData()
        self.updateTitle()
      })
    }
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    song: Song
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    cell.display(
      playable: song,
      displayMode: .add,
      playContextCb: nil,
      rootView: self,
      isDislayAlbumTrackNumberStyle: true,
      isMarked: addToPlaylistManager.contains(playable: song)
    )
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)

    let item = fetchedResultsController.getWrappedEntity(at: indexPath)
    if let cell = tableView.cellForRow(at: indexPath) as? PlayableTableCell {
      addToPlaylistManager.toggleSelection(playable: item, rootVC: self) {
        cell.isMarked = $0
        cell.refresh()
        self.updateTitle()
      }
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController.search(
      searchText: searchController.searchBar.text ?? "",
      onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1
    )
    tableView.reloadData()
  }
}
