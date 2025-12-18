//
//  PlaylistAddGenreDetailVC.swift
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

class PlaylistAddGenreDetailVC: MultiSourceTableViewController, PlaylistVCAddable {
  override var sceneTitle: String? { genre.name }

  public var addToPlaylistManager = AddToPlaylistManager()

  private var artistsFetchedResultsController: GenreArtistsFetchedResultsController!
  private var albumsFetchedResultsController: GenreAlbumsFetchedResultsController!
  private var songsFetchedResultsController: GenreSongsFetchedResultsController!
  private var doneButton: UIBarButtonItem!

  private let genre: Genre

  init(account: Account, genre: Genre) {
    self.genre = genre
    super.init(style: .grouped, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    doneButton = addToPlaylistManager.createDoneButton()
    navigationItem.rightBarButtonItems = [doneButton]

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
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    artistsFetchedResultsController?.delegate = self
    albumsFetchedResultsController?.delegate = self
    songsFetchedResultsController?.delegate = self
    updateTitle()
    addToPlaylistManager.configuteToolbar(
      viewVC: self,
      selectButtonSelector: #selector(selectAllButtonPressed)
    )

    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    Task { @MainActor in do {
      try await genre.fetch(
        storage: self.appDelegate.storage,
        librarySyncer: self.appDelegate.getMeta(account.info).librarySyncer,
        playableDownloadManager: self.appDelegate.getMeta(account.info)
          .playableDownloadManager
      )
    } catch {
      self.appDelegate.eventLogger.report(topic: "Genre Sync", error: error)
    }}
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    artistsFetchedResultsController?.delegate = nil
    albumsFetchedResultsController?.delegate = nil
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
    3
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    switch section + 1 {
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
    switch section + 1 {
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
    switch indexPath.section + 1 {
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
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    switch section + 1 {
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
    switch indexPath.section + 1 {
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
    switch indexPath.section + 1 {
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
    switch indexPath.section + 1 {
    case LibraryElement.Artist.rawValue:
      let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      let nextVC = PlaylistAddArtistDetailVC(account: account, artist: artist)
      nextVC.addToPlaylistManager = addToPlaylistManager
      navigationController?.pushViewController(nextVC, animated: true)
    case LibraryElement.Album.rawValue:
      let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(
        row: indexPath.row,
        section: 0
      ))
      let nextVC = PlaylistAddAlbumDetailVC(account: account, album: album)
      nextVC.addToPlaylistManager = addToPlaylistManager
      navigationController?.pushViewController(nextVC, animated: true)
    case LibraryElement.Song.rawValue:
      tableView.deselectRow(at: indexPath, animated: false)
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
      section = LibraryElement.Artist.rawValue - 1
    case albumsFetchedResultsController.fetchResultsController:
      section = LibraryElement.Album.rawValue - 1
    case songsFetchedResultsController.fetchResultsController:
      section = LibraryElement.Song.rawValue - 1
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
