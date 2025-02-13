//
//  PlaylistAddPlaylistDetailVC.swift
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

class PlaylistAddPlaylistDetailVC: SingleSnapshotFetchedResultsTableViewController<PlaylistItemMO>,
  PlaylistVCAddable {
  override var sceneTitle: String? { playlist.name }

  public var playlist: Playlist!
  public var addToPlaylistManager = AddToPlaylistManager()

  private var fetchedResultsController: PlaylistItemsFetchedResultsController!
  private var doneButton: UIBarButtonItem!

  override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    let source =
      PlaylistDetailDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        guard let object = try? self.appDelegate.storage.main.context
          .existingObject(with: objectID),
          let playlistItemMO = object as? PlaylistItemMO
        else {
          return UITableViewCell()
        }
        let playlistItem = PlaylistItem(
          library: self.appDelegate.storage.main.library,
          managedObject: playlistItemMO
        )
        return self.createCell(tableView, forRowAt: indexPath, playlistItem: playlistItem)
      }
    source.playlist = playlist
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

    appDelegate.userStatistics.visited(.playlistDetail)
    fetchedResultsController = PlaylistItemsFetchedResultsController(
      forPlaylist: playlist,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()

    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()
    addToPlaylistManager.configuteToolbar(
      viewVC: self,
      selectButtonSelector: #selector(selectAllButtonPressed)
    )

    guard appDelegate.storage.settings.isOnlineMode else { return }
    Task { @MainActor in do {
      try await playlist.fetch(
        storage: self.appDelegate.storage,
        librarySyncer: self.appDelegate.librarySyncer,
        playableDownloadManager: self.appDelegate.playableDownloadManager
      )
    } catch {
      self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
    }}
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    addToPlaylistManager.hideToolbar(viewVC: self)
  }

  @IBAction
  func selectAllButtonPressed(_ sender: UIBarButtonItem) {
    let songs = singleFetchedResultsController?
      .fetchedObjects?
      .compactMap { PlaylistItem(library: self.appDelegate.storage.main.library, managedObject: $0)
      }
      .compactMap { $0.playable }
    if let songs = songs {
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
    playlistItem: PlaylistItem
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    if let song = playlistItem.playable.asSong {
      cell.display(
        playable: song,
        displayMode: .add,
        playContextCb: nil,
        rootView: self,
        isMarked: addToPlaylistManager.contains(playable: song)
      )
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)

    let item = fetchedResultsController.getWrappedEntity(at: indexPath)
    if let cell = tableView.cellForRow(at: indexPath) as? PlayableTableCell,
       let song = item.playable.asSong {
      addToPlaylistManager.toggleSelection(playable: song, rootVC: self) {
        cell.isMarked = $0
        cell.refresh()
        self.updateTitle()
      }
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController.search(onlyCachedSongs: appDelegate.storage.settings.isOfflineMode)
    tableView.reloadData()
  }
}
