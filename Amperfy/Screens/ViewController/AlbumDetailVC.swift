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
    super.init(style: .plain, account: account)
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
      isGroupedInAlphabeticSections: true // sections are the album's discs
    )
    singleFetchedResultsController = fetchedResultsController
    singleFetchedResultsController?.delegate = self
    singleFetchedResultsController?.fetch()
    updateDiscTitles()
    snapshotDidChange = { [weak self] in self?.updateDiscTitles() }

    configureSearchController(
      placeholder: "Search in \"Album\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    tableView.register(nibName: PlayableTableCell.typeName)
    // Catalyst also need an estimate to calculate the correct height before scrolling
    tableView.reloadOnTextSizeChange { PlayableTableCell.rowHeight }
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: { "\(self.album.songCount) Song\(self.album.songCount == 1 ? "" : "s")" },
      playContextCb: { () in
        let isCachedOnly = self.searchController.searchBar.isCachedScopeSelected
        let songs = self.fetchedResultsController.getContextSongs(onlyCachedSongs: isCachedOnly)
        return PlayContext(containable: self.album, playables: songs ?? [])
      },
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
      .getContextSongs(onlyCachedSongs: searchController.searchBar.isCachedScopeSelected)
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

  /// Only albums with two or more discs show a "Disc n" header above each disc's songs.
  /// Decided on the whole album, so a search keeps the headers.
  private var isMultiDisc = false
  /// Header title per section. The sections follow the raw disk strings ("1", "01" and "1/2"
  /// are different sections), so only the first section of a disc gets a title.
  private var discTitles = [String?]()

  private func updateDiscTitles() {
    let discNumbers = (fetchedResultsController.sections ?? []).map { section in
      (section.objects?.first as? SongMO).flatMap { Song(managedObject: $0).discNumber }
    }
    if !fetchedResultsController.isSearchActive {
      isMultiDisc = Set(discNumbers.compactMap { $0 }).count > 1
    }
    var seenDiscs = Set<Int>()
    let titles: [String?] = discNumbers.map { disc in
      guard isMultiDisc, let disc, seenDiscs.insert(disc).inserted else { return nil }
      return "Disc \(disc)"
    }
    guard titles != discTitles else { return }
    discTitles = titles
    tableView.reloadData()
  }

  private func discTitle(inSection section: Int) -> String? {
    discTitles.indices.contains(section) ? discTitles[section] : nil
  }

  override func tableView(
    _ tableView: UITableView,
    viewForHeaderInSection section: Int
  )
    -> UIView? {
    guard let title = discTitle(inSection: section) else { return nil }
    let header = DiscHeaderView()
    var content = UIListContentConfiguration.header()
    content.text = title
    content.textProperties.font = .preferredFont(forTextStyle: .headline)
    content.textProperties.color = .secondaryLabel
    // a bit more room around the title, relative to the system margins
    content.directionalLayoutMargins.top *= 2
    content.directionalLayoutMargins.bottom *= 2
    header.contentConfiguration = content
    return header
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    discTitle(inSection: section) != nil ? UITableView.automaticDimension : 0.0
  }

  /// Self-sizing needs an estimate, the table disables estimates for all other headers.
  override func tableView(
    _ tableView: UITableView,
    estimatedHeightForHeaderInSection section: Int
  )
    -> CGFloat {
    discTitle(inSection: section) != nil ? UITableView.automaticDimension : 0.0
  }

  override func updateSearchResults(for searchController: UISearchController) {
    fetchedResultsController.search(
      searchText: searchController.searchBar.text ?? "",
      onlyCachedSongs: searchController.searchBar.isCachedScopeSelected
    )
    tableView.reloadData()
  }
}

// MARK: - DiscHeaderView

/// Mac: the table adds its scroll edge effect ("scroll pocket") interactions to the section
/// headers, which makes the top edge effect blur the whole album header. The disc headers don't
/// take part in the edge effect, they have their own blur instead.
private final class DiscHeaderView: UITableViewHeaderFooterView {
  #if targetEnvironment(macCatalyst)
    override func addInteraction(_ interaction: UIInteraction) {
      // the interactions are private (_UIScrollPocketContainerInteraction, _UIScrollPocketInteraction)
      guard !String(describing: type(of: interaction)).hasPrefix("_UIScrollPocket") else { return }
      super.addInteraction(interaction)
    }
  #endif
}
