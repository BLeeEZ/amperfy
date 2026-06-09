//
//  SavedQueueDetailVC.swift
//  Amperfy
//
//  Created by Amperfy Contributors on 09.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

class SavedQueueDetailVC: BasicTableViewController {
  override var sceneTitle: String? { savedQueue.name }

  private let account: Account
  private let savedQueue: SavedQueue
  private var resolvedSongs: [Song] = []
  private var detailHeaderView: LibraryElementDetailTableHeaderView?

  init(account: Account, savedQueue: SavedQueue) {
    self.account = account
    self.savedQueue = savedQueue
    super.init(style: .grouped)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    setNavBarTitle(title: savedQueue.name)
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0
    tableView.backgroundColor = .backgroundColor

    let optionsButton = UIBarButtonItem.createOptionsBarButton()
    optionsButton.menu = makeMenu()
    navigationItem.rightBarButtonItem = optionsButton

    resolveSongs()

    let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
      infoCB: {
        "\(self.resolvedSongs.count) Song\(self.resolvedSongs.count == 1 ? "" : "s")"
      },
      playContextCb: { [weak self] in self?.makePlayContext() },
      player: appDelegate.player,
      isInfoAlwaysHidden: false
    )
    detailHeaderView = LibraryElementDetailTableHeaderView.createTableHeader(
      rootView: self,
      configuration: playShuffleInfoConfig
    )

    containableAtIndexPathCallback = { [weak self] indexPath in
      guard let self, indexPath.row < self.resolvedSongs.count else { return nil }
      return self.resolvedSongs[indexPath.row]
    }
    playContextAtIndexPathCallback = { [weak self] indexPath in
      self?.makePlayContext(startingAt: indexPath.row)
    }
    swipeCallback = { [weak self] indexPath, completionHandler in
      guard let self, indexPath.row < self.resolvedSongs.count else {
        completionHandler(nil)
        return
      }
      let song = self.resolvedSongs[indexPath.row]
      let playContext = self.makePlayContext(startingAt: indexPath.row)
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
    detailHeaderView?.refresh()
  }

  private func resolveSongs() {
    let allIds = Set(savedQueue.contextSongIds + savedQueue.userQueueSongIds)
    let fetched = appDelegate.storage.main.library.getSongs(for: account, ids: allIds)
    let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    resolvedSongs = (savedQueue.contextSongIds + savedQueue.userQueueSongIds)
      .compactMap { byId[$0] }
    tableView.reloadData()
  }

  private func makePlayContext(startingAt index: Int? = nil) -> PlayContext {
    let savedIndex = max(0, Int(savedQueue.currentIndex))
    let startIndex = index ?? min(savedIndex, max(0, resolvedSongs.count - 1))
    return PlayContext(
      name: savedQueue.name,
      type: .music,
      index: startIndex,
      playables: resolvedSongs.map { $0 as AbstractPlayable }
    )
  }

  private func makeMenu() -> UIMenu {
    let saveAsPlaylist = UIAction(
      title: "Save as Playlist",
      image: UIImage(systemName: "square.and.arrow.down")
    ) { [weak self] _ in
      self?.promptSaveAsPlaylist()
    }
    let delete = UIAction(
      title: "Delete",
      image: UIImage(systemName: "trash"),
      attributes: .destructive
    ) { [weak self] _ in
      guard let self else { return }
      self.appDelegate.savedQueues.delete(self.savedQueue)
      self.navigationController?.popViewController(animated: true)
    }
    return UIMenu(children: [saveAsPlaylist, delete])
  }

  private func promptSaveAsPlaylist() {
    let alert = UIAlertController(title: "Save as Playlist", message: nil, preferredStyle: .alert)
    alert.addTextField { tf in tf.text = self.savedQueue.name }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      let name = alert.textFields?.first?.text ?? self.savedQueue.name
      Task { @MainActor in
        do {
          let syncer = self.appDelegate.getMeta(self.account.info).librarySyncer
          _ = try await self.appDelegate.savedQueues.saveAsPlaylist(
            self.savedQueue,
            name: name,
            librarySyncer: syncer
          )
          self.appDelegate.eventLogger.info(
            topic: "Save as Playlist",
            message: "Saved \"\(name)\" as a playlist."
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Save as Playlist", error: error)
        }
      }
    })
    present(alert, animated: true)
  }

  override func tableView(
    _ tableView: UITableView,
    numberOfRowsInSection section: Int
  )
    -> Int {
    resolvedSongs.count
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    let song = resolvedSongs[indexPath.row]
    cell.display(
      playable: song,
      playContextCb: convertCellViewToPlayContext,
      rootView: self
    )
    return cell
  }

  override func tableView(
    _ tableView: UITableView,
    didSelectRowAt indexPath: IndexPath
  ) {
    let playContext = makePlayContext(startingAt: indexPath.row)
    appDelegate.player.play(context: playContext)
    tableView.deselectRow(at: indexPath, animated: true)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell) else { return nil }
    return makePlayContext(startingAt: indexPath.row)
  }
}
