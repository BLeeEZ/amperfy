//
//  PlaylistDetailVC.swift
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

// MARK: - PlaylistDetailDiffableDataSource

class PlaylistDetailDiffableDataSource: BasicUITableViewDiffableDataSource {
  var playlist: Playlist!
  var isMoveAllowed = false
  var isEditAllowed = true

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    isMoveAllowed
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return true to be enable swipe
    isEditAllowed
  }

  override func tableView(
    _ tableView: UITableView,
    moveRowAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    exectueAfterAnimation {
      self.playlist?.movePlaylistItem(fromIndex: sourceIndexPath.row, to: destinationIndexPath.row)

      guard self.appDelegate.storage.settings.user.isOnlineMode,
            let account = self.playlist.account else { return }
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer
          .syncUpload(playlistToUpdateOrder: self.playlist)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Upload Order Update", error: error)
      }}
    }
    super.tableView(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath)
  }

  override func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    guard editingStyle == .delete else { return }
    exectueAfterAnimation {
      self.playlist?.remove(at: indexPath.row)
      guard self.appDelegate.storage.settings.user.isOnlineMode,
            let account = self.playlist.account else { return }
      Task { @MainActor in do {
        try await self.appDelegate.getMeta(account.info).librarySyncer.syncUpload(
          playlistToDeleteSong: self.playlist,
          index: indexPath.row
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Upload Entry Remove", error: error)
      }}
    }
    super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
  }
}

// MARK: - PlaylistDetailVC

class PlaylistDetailVC: SingleSnapshotFetchedResultsTableViewController<PlaylistItemMO> {
  override var sceneTitle: String? { playlist.name }

  private var fetchedResultsController: PlaylistItemsFetchedResultsController!
  let playlist: Playlist

  private var editButton: UIBarButtonItem!
  private var optionsButton: UIBarButtonItem!
  var detailOperationsView: GenericDetailTableHeader?

  init(account: Account, playlist: Playlist) {
    self.playlist = playlist
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

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

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

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
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    // Use a single button, two buttons don't work on catalyst
    editButton = UIBarButtonItem(
      title: "Edit",
      style: .plain,
      target: self,
      action: #selector(openEditView)
    )
    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = UIMenu.lazyMenu {
      EntityPreviewActionBuilder(container: self.playlist, on: self).createMenuActions()
    }

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: { "\(self.playlist.songCount) Song\(self.playlist.songCount == 1 ? "" : "s")" },
      playContextCb: { () in PlayContext(
        containable: self.playlist,
        playables: self.fetchedResultsController
          .getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.user.isOfflineMode) ??
          []
      ) },
      player: appDelegate.player,
      isInfoAlwaysHidden: true
    )
    let detailHeaderConfig = DetailHeaderConfiguration(
      entityContainer: playlist,
      rootView: self,
      tableView: tableView,
      playShuffleInfoConfig: playShuffleInfoConfig
    )
    detailOperationsView = GenericDetailTableHeader
      .createTableHeader(configuration: detailHeaderConfig)
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    snapshotDidChange = detailOperationsView?.refresh

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath).playable
    }
    playContextAtIndexPathCallback = { indexPath in
      self.convertIndexPathToPlayContext(songIndexPath: indexPath)
    }
    swipeCallback = { indexPath, completionHandler in
      let playlistItem = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
      completionHandler(SwipeActionContext(
        containable: playlistItem.playable,
        playContext: playContext
      ))
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = false
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    if appDelegate.storage.settings.user.isOfflineMode {
      tableView.isEditing = false
    }
    refreshBarButtons()
    Task { @MainActor in
      do {
        try await playlist.fetch(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
            .playableDownloadManager
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
      }
      self.detailOperationsView?.refresh()
    }
  }

  func refreshBarButtons() {
    var edititingBarButton: UIBarButtonItem? = nil

    if appDelegate.storage.settings.user.isOnlineMode {
      edititingBarButton = editButton
      edititingBarButton?.title = "Edit"
      edititingBarButton?.style = .plain
      if playlist.isSmartPlaylist {
        edititingBarButton?.isEnabled = false
      }
    }

    navigationItem.rightBarButtonItems = [optionsButton, edititingBarButton].compactMap { $0 }
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
    guard let songs = fetchedResultsController
      .getContextSongs(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    else { return nil }
    return PlayContext(containable: playlist, index: songIndexPath.row, playables: songs)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell)
    else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
  }

  @objc
  private func openEditView(sender: UIBarButtonItem) {
    let playlistDetailVC = AppStoryboard.Main.segueToPlaylistEdit(
      account: account,
      playlist: playlist
    )
    let playlistDetailNav = UINavigationController(rootViewController: playlistDetailVC)
    playlistDetailVC.onDoneCB = {
      self.detailOperationsView?.refresh()
      self.tableView.reloadData()
    }
    present(playlistDetailNav, animated: true, completion: nil)
  }

  func createCell(
    _ tableView: UITableView,
    forRowAt indexPath: IndexPath,
    playlistItem: PlaylistItem
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    if let song = playlistItem.playable.asSong {
      cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
    }
    return cell
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController
      .search(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    tableView.reloadData()
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    Task { @MainActor in
      do {
        try await self.appDelegate.getMeta(self.account.info).librarySyncer
          .syncDown(playlist: playlist)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
      }
      self.detailOperationsView?.refresh()
      self.refreshControl?.endRefreshing()
    }
  }
}
