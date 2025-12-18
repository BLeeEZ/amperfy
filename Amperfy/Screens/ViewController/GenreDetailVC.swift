//
//  GenreDetailVC.swift
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

class GenreDetailVC: MultiSourceTableViewController {
  override var sceneTitle: String? { genre.name }

  private let genre: Genre

  private var artistsFetchedResultsController: GenreArtistsFetchedResultsController!
  private var albumsFetchedResultsController: GenreAlbumsFetchedResultsController!
  private var songsFetchedResultsController: GenreSongsFetchedResultsController!
  private var optionsButton: UIBarButtonItem!
  private var detailOperationsView: GenericDetailTableHeader?

  init(account: Account, genre: Genre) {
    self.genre = genre
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    appDelegate.userStatistics.visited(.genreDetail)

    optionsButton = UIBarButtonItem.createOptionsBarButton()

    artistsFetchedResultsController = GenreArtistsFetchedResultsController(
      for: genre,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    artistsFetchedResultsController.delegate = self
    albumsFetchedResultsController = GenreAlbumsFetchedResultsController(
      for: genre,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    albumsFetchedResultsController.delegate = self
    songsFetchedResultsController = GenreSongsFetchedResultsController(
      for: genre,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    songsFetchedResultsController.delegate = self
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    configureSearchController(
      placeholder: "Artists, Albums and Songs",
      scopeButtonTitles: ["All", "Cached"]
    )
    setNavBarTitle(title: genre.name)

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: {
        "\(self.genre.artistCount) Artist\(self.genre.artistCount == 1 ? "" : "s") \(CommonString.oneMiddleDot) \(self.genre.albumCount) Album\(self.genre.albumCount == 1 ? "" : "s") \(CommonString.oneMiddleDot) \(self.genre.songCount) Song\(self.genre.songCount == 1 ? "" : "s")"
      },
      playContextCb: { () in PlayContext(
        containable: self.genre,
        playables: self.songsFetchedResultsController
          .getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.user.isOfflineMode) ??
          []
      ) },
      player: appDelegate.player,
      isInfoAlwaysHidden: true
    )
    let detailHeaderConfig = DetailHeaderConfiguration(
      entityContainer: genre,
      rootView: self,
      tableView: tableView,
      playShuffleInfoConfig: playShuffleInfoConfig
    )
    detailOperationsView = GenericDetailTableHeader
      .createTableHeader(configuration: detailHeaderConfig)

    optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = UIMenu.lazyMenu {
      EntityPreviewActionBuilder(container: self.genre, on: self).createMenuActions()
    }
    navigationItem.rightBarButtonItem = optionsButton

    containableAtIndexPathCallback = { indexPath in
      switch indexPath.section + 0 {
      case LibraryElement.Artist.rawValue:
        return self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
      case LibraryElement.Album.rawValue:
        return self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
      case LibraryElement.Song.rawValue:
        return self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
      default:
        return nil
      }
    }
    playContextAtIndexPathCallback = { indexPath in
      switch indexPath.section + 0 {
      case LibraryElement.Artist.rawValue:
        let entity = self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
        return PlayContext(containable: entity)
      case LibraryElement.Album.rawValue:
        let entity = self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
        return PlayContext(containable: entity)
      case LibraryElement.Song.rawValue:
        let entity = self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
        return PlayContext(containable: entity)
      default:
        return nil
      }
    }
    swipeCallback = { indexPath, completionHandler in
      switch indexPath.section + 0 {
      case LibraryElement.Artist.rawValue:
        let artist = self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
        Task { @MainActor in
          do {
            try await artist.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(self.account.info)
                .playableDownloadManager
            )
          } catch {
            self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
          }
          completionHandler(SwipeActionContext(containable: artist))
        }
      case LibraryElement.Album.rawValue:
        let album = self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
          row: indexPath.row,
          section: 0
        ))
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
          completionHandler(SwipeActionContext(containable: album))
        }
      case LibraryElement.Song.rawValue:
        let songIndexPath = IndexPath(row: indexPath.row, section: 0)
        let song = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        let playContext = self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
        completionHandler(SwipeActionContext(containable: song, playContext: playContext))
      default:
        completionHandler(nil)
      }
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = false
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    artistsFetchedResultsController?.delegate = self
    albumsFetchedResultsController?.delegate = self
    songsFetchedResultsController?.delegate = self

    Task { @MainActor in
      do {
        try await genre.fetch(
          storage: self.appDelegate.storage,
          librarySyncer: self.appDelegate.getMeta(self.account.info).librarySyncer,
          playableDownloadManager: self.appDelegate.getMeta(self.account.info)
            .playableDownloadManager
        )
      } catch {
        self.appDelegate.eventLogger.report(topic: "Genre Sync", error: error)
      }
      self.detailOperationsView?.refresh()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    artistsFetchedResultsController?.delegate = nil
    albumsFetchedResultsController?.delegate = nil
    songsFetchedResultsController?.delegate = nil
  }

  func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
    guard let songs = songsFetchedResultsController
      .getContextSongs(onlyCachedSongs: appDelegate.storage.settings.user.isOfflineMode)
    else { return nil }
    let selectedSong = songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
    guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
    return PlayContext(containable: genre, index: playContextIndex, playables: songs)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell),
          indexPath.section + 0 == LibraryElement.Song.rawValue
    else { return nil }
    return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    // 3 section + 1 top section. The top section is needed due to display bugs
    4
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    switch section + 0 {
    case LibraryElement.Artist.rawValue:
      return "Artists"
    case LibraryElement.Album.rawValue:
      return "Albums"
    case LibraryElement.Song.rawValue:
      return "Songs"
    default:
      return ""
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section + 0 {
    case LibraryElement.Artist.rawValue:
      return artistsFetchedResultsController.sections?[0].numberOfObjects ?? 0
    case LibraryElement.Album.rawValue:
      return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0
    case LibraryElement.Song.rawValue:
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
    switch indexPath.section + 0 {
    case LibraryElement.Artist.rawValue:
      let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
      let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      cell.display(container: artist, rootView: self)
      return cell
    case LibraryElement.Album.rawValue:
      let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
      let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      cell.display(container: album, rootView: self)
      return cell
    case LibraryElement.Song.rawValue:
      let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
      let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
      return cell
    default:
      return UITableViewCell()
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    switch section + 0 {
    case LibraryElement.Artist.rawValue:
      return artistsFetchedResultsController.sections?[0]
        .numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
    case LibraryElement.Album.rawValue:
      return albumsFetchedResultsController.sections?[0]
        .numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
    case LibraryElement.Song.rawValue:
      return songsFetchedResultsController.sections?[0]
        .numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
    default:
      return 0.0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    switch indexPath.section + 0 {
    case LibraryElement.Artist.rawValue:
      return GenericTableCell.rowHeight
    case LibraryElement.Album.rawValue:
      return GenericTableCell.rowHeight
    case LibraryElement.Song.rawValue:
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
    switch indexPath.section + 0 {
    case LibraryElement.Artist.rawValue:
      return GenericTableCell.rowHeight
    case LibraryElement.Album.rawValue:
      return GenericTableCell.rowHeight
    case LibraryElement.Song.rawValue:
      return PlayableTableCell.rowHeight
    default:
      return 0.0
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch indexPath.section + 0 {
    case LibraryElement.Artist.rawValue:
      let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToArtistDetail(account: account, artist: artist),
        animated: true
      )
    case LibraryElement.Album.rawValue:
      let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToAlbumDetail(account: account, album: album),
        animated: true
      )
    case LibraryElement.Song.rawValue: break
    default: break
    }
  }

  override func updateSearchResults(for searchController: UISearchController) {
    guard let searchText = searchController.searchBar.text else { return }
    if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 0 {
      artistsFetchedResultsController.search(searchText: searchText, onlyCached: false)
      albumsFetchedResultsController.search(searchText: searchText, onlyCached: false)
      songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
    } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
      artistsFetchedResultsController.search(searchText: searchText, onlyCached: true)
      albumsFetchedResultsController.search(searchText: searchText, onlyCached: true)
      songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
    } else {
      artistsFetchedResultsController.showAllResults()
      albumsFetchedResultsController.showAllResults()
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
    case artistsFetchedResultsController.fetchResultsController:
      section = LibraryElement.Artist.rawValue - 0
    case albumsFetchedResultsController.fetchResultsController:
      section = LibraryElement.Album.rawValue - 0
    case songsFetchedResultsController.fetchResultsController:
      section = LibraryElement.Song.rawValue - 0
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
