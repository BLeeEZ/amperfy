//
//  PlaylistAddLibraryVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.12.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import Collections
import CoreData
import UIKit

// MARK: - PlaylistVCAddable

@MainActor
public protocol PlaylistVCAddable: UIViewController {
  var addToPlaylistManager: AddToPlaylistManager { get set }
}

extension LibraryDisplayType {
  public func getVCForPlaylistAdd(account: Account) -> PlaylistVCAddable? {
    switch self {
    case .genres:
      let vc = PlaylistAddGenresVC(account: account)
      return vc
    case .artists:
      let vc = PlaylistAddArtistsVC(account: account)
      vc.displayFilter = .all
      return vc
    case .favoriteArtists:
      let vc = PlaylistAddArtistsVC(account: account)
      vc.displayFilter = .favorites
      return vc
    case .newestAlbums:
      let vc = PlaylistAddAlbumsVC(account: account)
      vc.displayFilter = .newest
      return vc
    case .recentAlbums:
      let vc = PlaylistAddAlbumsVC(account: account)
      vc.displayFilter = .recent
      return vc
    case .favoriteAlbums:
      let vc = PlaylistAddAlbumsVC(account: account)
      vc.displayFilter = .favorites
      return vc
    case .albums:
      let vc = PlaylistAddAlbumsVC(account: account)
      vc.displayFilter = .all
      return vc
    case .songs:
      let vc = PlaylistAddSongsVC(account: account)
      vc.displayFilter = .all
      return vc
    case .favoriteSongs:
      let vc = PlaylistAddSongsVC(account: account)
      vc.displayFilter = .favorites
      return vc
    case .playlists:
      let vc = PlaylistAddPlaylistsVC(account: account)
      return vc
    case .directories:
      let vc = PlaylistAddMusicFoldersVC(account: account)
      return vc
    default:
      return nil
    }
  }
}

public typealias SelectedCallback = (Bool) -> ()

// MARK: - AddToPlaylistManager

@MainActor
public class AddToPlaylistManager {
  public var playlist: Playlist!
  public var onDoneCB: VoidFunctionCallback?
  public var elementsToAdd = [AbstractPlayable]()
  public var rootView: UIViewController?

  private var appDelegate: AppDelegate
  private static let warningElementsToAddCount = 100

  init() {
    self.appDelegate = (UIApplication.shared.delegate as! AppDelegate)
  }

  var title: String {
    let count = elementsToAdd.count
    if count != 0 {
      return "Add \(elementsToAdd.count) Songs to \"\(playlist.name)\""
    } else {
      return "Add Songs to \"\(playlist.name)\""
    }
  }

  func contains(playable: AbstractPlayable) -> Bool {
    elementsToAdd.contains(where: {
      $0 == playable
    })
  }

  func toggleSelection(
    playables: [AbstractPlayable],
    rootVC: UIViewController,
    doneCB: @escaping VoidFunctionCallback
  ) {
    let elementsToAddSet = OrderedSet<AbstractPlayable>(elementsToAdd)
    let playableToToggleSet = OrderedSet<AbstractPlayable>(playables)
    let itemsAlreadyAboutToGetAdded = elementsToAddSet.intersection(playableToToggleSet)
    guard itemsAlreadyAboutToGetAdded.isEmpty else {
      // unselect all provided playables
      elementsToAdd = Array(elementsToAddSet.subtracting(itemsAlreadyAboutToGetAdded))
      doneCB()
      return
    }

    func handleSuccessfullSelection(playables: [AbstractPlayable]) {
      elementsToAdd.append(contentsOf: playables)
      doneCB()
    }
    let itemsNotContained = playlist.notContaines(playables: playables)
    if itemsNotContained.count != playableToToggleSet.count {
      let useSingular = (playableToToggleSet.count == 1)
      let pluralS = useSingular ? "" : "s"
      let alertTitle = useSingular ?
        "This Song is already in your Playlist." :
        "Some Songs are already in your Playlist."
      let alert = UIAlertController(title: nil, message: alertTitle, preferredStyle: .alert)
      alert.addAction(UIAlertAction(
        title: "Add Duplicate\(pluralS)",
        style: .default,
        handler: { _ in
          handleSuccessfullSelection(playables: playables)
        }
      ))
      alert.addAction(UIAlertAction(
        title: "Skip\(useSingular ? "" : " Duplicates")",
        style: useSingular ? .cancel : .default,
        handler: { _ in
          handleSuccessfullSelection(playables: Array(itemsNotContained))
        }
      ))
      if !useSingular {
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
          // do nothing
          doneCB()
        }))
      }
      rootVC.present(alert, animated: true, completion: nil)
    } else {
      handleSuccessfullSelection(playables: playables)
    }
  }

  func toggleSelection(
    playable: AbstractPlayable,
    rootVC: UIViewController,
    isSelectedCB: @escaping SelectedCallback
  ) {
    let markedIndex = elementsToAdd.firstIndex { $0 == playable }
    if let markedIndex = markedIndex {
      elementsToAdd.remove(at: markedIndex)
      isSelectedCB(false)
    } else {
      append(playable: playable, rootVC: rootVC, isSelectedCB: isSelectedCB)
    }
  }

  private func append(
    playable: AbstractPlayable,
    rootVC: UIViewController,
    isSelectedCB: @escaping SelectedCallback
  ) {
    func handleSuccessfullSelection(playables: [AbstractPlayable]) {
      elementsToAdd.append(playable)
      isSelectedCB(true)
    }
    let itemsNotContained = playlist.notContaines(playables: [playable])
    if itemsNotContained.isEmpty {
      let alert = UIAlertController(
        title: nil,
        message: "This Song is already in your Playlist.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Add Duplicate", style: .default, handler: { _ in
        handleSuccessfullSelection(playables: [playable])
      }))
      alert.addAction(UIAlertAction(title: "Skip", style: .cancel, handler: { _ in
        isSelectedCB(false)
      }))
      rootVC.present(alert, animated: true, completion: nil)
    } else {
      handleSuccessfullSelection(playables: [playable])
    }
  }

  func remove(playable: AbstractPlayable) {
    elementsToAdd.removeAll(where: { $0 == playable })
  }

  func createDoneButton() -> UIBarButtonItem {
    UIBarButtonItem(
      title: "Done",
      style: .plain,
      target: self,
      action: #selector(doneBarButtonPressed)
    )
  }

  @IBAction
  func doneBarButtonPressed(_ sender: UIBarButtonItem) {
    let songsToAdd = elementsToAdd.filterSongs()
    guard !songsToAdd.isEmpty else {
      rootView?.dismiss(animated: true, completion: nil)
      return
    }

    func uploadPlaylistChanges() {
      rootView?.dismiss(animated: true, completion: nil)

      Task { @MainActor in
        do {
          if let account = playlist.account {
            try await self.appDelegate.getMeta(account.info).librarySyncer.syncUpload(
              playlistToAddSongs: playlist,
              songs: songsToAdd
            )
          }
          self.playlist.append(playables: songsToAdd)
          self.onDoneCB?()
        } catch {
          self.appDelegate.eventLogger.report(topic: "Add Songs to Playlist", error: error)
        }
        if songsToAdd.count > Self.warningElementsToAddCount {
          self.appDelegate.eventLogger.info(
            topic: "Add Songs to Playlist",
            message: "The Playlist \"\(self.playlist.name)\" has been successfully synced to the server."
          )
        }
      }
    }

    if songsToAdd.count > Self.warningElementsToAddCount {
      let alert = UIAlertController(
        title: nil,
        message: "Adding \(songsToAdd.count) Songs to this Playlist may cause performance issues during server synchronization.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Add Songs Anyway", style: .default, handler: { _ in
        uploadPlaylistChanges()
      }))
      alert.addAction(UIAlertAction(title: "Abort", style: .default, handler: { _ in
        self.rootView?.dismiss(animated: true, completion: nil)
      }))
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
        // do nothing
      }))
      rootView?.present(alert, animated: true, completion: nil)
    } else {
      uploadPlaylistChanges()
    }
  }

  public func configuteToolbar(viewVC: UIViewController, selectButtonSelector: Selector) {
    viewVC.navigationController?.setToolbarHidden(false, animated: false)
    let flexible = UIBarButtonItem(
      barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
      target: self,
      action: nil
    )
    let selectAllBarButton = UIBarButtonItem(
      title: "All",
      style: .plain,
      target: viewVC,
      action: selectButtonSelector
    )
    viewVC.toolbarItems = [selectAllBarButton, flexible]
  }

  public func hideToolbar(viewVC: UIViewController) {
    viewVC.navigationController?.setToolbarHidden(true, animated: false)
  }
}

// MARK: - PlaylistAddLibraryVC

class PlaylistAddLibraryVC: KeyCommandTableViewController {
  override var sceneTitle: String? { addToPlaylistManager.playlist.name }

  private var doneButton: UIBarButtonItem!
  private var closeButton: UIBarButtonItem!
  private var libraryItems = [LibraryNavigatorItem]()

  public let addToPlaylistManager = AddToPlaylistManager()
  private let account: Account!

  init(account: Account) {
    self.account = account
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.typeName)

    libraryItems = LibraryDisplaySettings.addToPlaylistSettings.inUse.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0
    ) }

    addToPlaylistManager.rootView = self
    doneButton = addToPlaylistManager.createDoneButton()
    closeButton = UIBarButtonItem.createCloseBarButton(
      target: self,
      selector: #selector(cancelBarButtonPressed)
    )
    navigationItem.leftItemsSupplementBackButton = true
    navigationItem.leftBarButtonItem = closeButton
    navigationItem.rightBarButtonItem = doneButton
  }

  func updateTitle() {
    setNavBarTitle(title: addToPlaylistManager.title)
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateTitle()
  }

  @IBAction
  func cancelBarButtonPressed(_ sender: Any) {
    dismiss()
  }

  private func dismiss() {
    dismiss(animated: true, completion: nil)
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: UITableViewCell.typeName),
          let libraryItem = libraryItems[indexPath.row].library
    else { return UITableViewCell() }

    var content = cell.defaultContentConfiguration()
    LibraryNavigatorConfigurator.configureForLibrary(
      contentView: &content,
      libraryItem: libraryItem
    )

    cell.accessoryType = .disclosureIndicator
    cell.contentConfiguration = content

    return cell
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    libraryItems.count
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    guard let nextVC = libraryItems[indexPath.row].library?.getVCForPlaylistAdd(account: account)
    else { return }
    nextVC.addToPlaylistManager = addToPlaylistManager
    navigationController?.pushViewController(nextVC, animated: true)
  }
}
