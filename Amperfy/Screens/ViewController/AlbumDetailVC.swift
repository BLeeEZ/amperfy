//
//  AlbumDetailVC.swift
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
import UIKit

// MARK: - AlbumDetailDiffableDataSource

class AlbumDetailDiffableDataSource: BasicUITableViewDiffableDataSource {
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    false
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return true to be enable swipe
    true
  }
}

// MARK: - AlbumDetailVC

class AlbumDetailVC: SingleSnapshotFetchedResultsTableViewController<SongMO> {
  override var sceneTitle: String? { album.name }

  var songToScrollTo: Song?
  private var fetchedResultsController: AlbumSongsFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  private var detailOperationsView: GenericDetailTableHeader?
  let album: Album

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
    appDelegate.userStatistics.visited(.albumDetail)

    optionsButton = UIBarButtonItem.createOptionsBarButton()

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
    // Catalyst also need an estimate to calculate the correct height before scrolling
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: { "\(self.album.songCount) Song\(self.album.songCount == 1 ? "" : "s")" },
      playContextCb: { () in PlayContext(
        containable: self.album,
        playables: self.fetchedResultsController
          .getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.user.isOfflineMode) ??
          []
      ) },
      player: appDelegate.player,
      isInfoAlwaysHidden: true
    )
    let detailHeaderConfig = DetailHeaderConfiguration(
      entityContainer: album,
      rootView: self,
      tableView: tableView,
      playShuffleInfoConfig: playShuffleInfoConfig
    )
    detailOperationsView = GenericDetailTableHeader
      .createTableHeader(configuration: detailHeaderConfig)

    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = UIMenu.lazyMenu {
      EntityPreviewActionBuilder(container: self.album, on: self).createMenuActions()
    }
    navigationItem.rightBarButtonItem = optionsButton

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath)
    }
    playContextAtIndexPathCallback = convertIndexPathToPlayContext
    swipeCallback = { indexPath, completionHandler in
      let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
      completionHandler(SwipeActionContext(containable: song, playContext: playContext))
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = false
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()

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
      self.detailOperationsView?.refresh()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    defer { songToScrollTo = nil }
    guard let songToScrollTo = songToScrollTo,
          let indexPath = fetchedResultsController.fetchResultsController
          .indexPath(forObject: songToScrollTo.managedObject)
    else { return }
    tableView.scrollToRow(at: indexPath, at: .top, animated: true)
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
    guard let songs = fetchedResultsController
      .getContextSongs(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    else { return nil }
    let selectedSong = fetchedResultsController.getWrappedEntity(at: songIndexPath)
    guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
    return PlayContext(containable: album, index: playContextIndex, playables: songs)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell) else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: indexPath)
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
      playContextCb: convertCellViewToPlayContext,
      rootView: self,
      isDislayAlbumTrackNumberStyle: true
    )
    return cell
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController.search(
      searchText: searchController.searchBar.text ?? "",
      onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1
    )
    tableView.reloadData()
  }
}
