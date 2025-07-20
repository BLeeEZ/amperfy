//
//  RadiosVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.12.24.
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
import CoreData
import UIKit

class RadiosVC: SingleFetchedResultsTableViewController<RadioMO> {
  override var sceneTitle: String? {
    "Radios"
  }

  private var fetchedResultsController: RadiosFetchedResultsController!
  private var detailHeaderView: LibraryElementDetailTableHeaderView?

  override func viewDidLoad() {
    super.viewDidLoad()

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    appDelegate.userStatistics.visited(.radios)

    fetchedResultsController = RadiosFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: true
    )
    singleFetchedResultsController = fetchedResultsController
    tableView.reloadData()

    configureSearchController(
      placeholder: "Search in \"\(sceneTitle ?? "")\"",
      showSearchBarAtEnter: true
    )
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.rowHeight = PlayableTableCell.rowHeight
    tableView.estimatedRowHeight = PlayableTableCell.rowHeight

    let playShuffleConfig = PlayShuffleInfoConfiguration(
      infoCB: {
        "\(self.fetchedResultsController.fetchedObjects?.count ?? 0) Radio\((self.fetchedResultsController.fetchedObjects?.count ?? 0) == 1 ? "" : "s")"
      },
      playContextCb: handleHeaderPlay,
      player: appDelegate.player,
      isInfoAlwaysHidden: false,
      isShuffleOnContextNeccessary: false,
      shuffleContextCb: handleHeaderShuffle
    )
    detailHeaderView = LibraryElementDetailTableHeaderView.createTableHeader(
      rootView: self,
      configuration: playShuffleConfig
    )
    refreshControl?.addTarget(
      self,
      action: #selector(Self.handleRefresh),
      for: UIControl.Event.valueChanged
    )

    containableAtIndexPathCallback = { indexPath in
      self.fetchedResultsController.getWrappedEntity(at: indexPath)
    }
    playContextAtIndexPathCallback = convertIndexPathToPlayContext
    swipeCallback = { indexPath, completionHandler in
      let radio = self.fetchedResultsController.getWrappedEntity(at: indexPath)
      let playContext = self.convertIndexPathToPlayContext(radioIndexPath: indexPath)
      completionHandler(SwipeActionContext(containable: radio, playContext: playContext))
    }
    setNavBarTitle(title: sceneTitle ?? "")
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    updateFromRemote()
  }

  func updateFromRemote() {
    guard appDelegate.storage.settings.isOnlineMode else { return }
    Task { @MainActor in
      do {
        try await self.appDelegate.librarySyncer.syncRadios()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Radios Sync", error: error)
      }
      self.detailHeaderView?.refresh()
      self.updateSearchResults(for: self.searchController)
    }
  }

  public func handleHeaderPlay() -> PlayContext {
    guard let displayedRadiosMO = fetchedResultsController.fetchedObjects else { return PlayContext(
      name: sceneTitle ?? "",
      playables: []
    ) }
    let radios = displayedRadiosMO.prefix(appDelegate.player.maxSongsToAddOnce)
      .compactMap { Radio(managedObject: $0) }
    return PlayContext(name: sceneTitle ?? "", playables: radios)
  }

  public func handleHeaderShuffle() -> PlayContext {
    guard let displayedRadiosMO = fetchedResultsController.fetchedObjects else { return PlayContext(
      name: sceneTitle ?? "",
      playables: []
    ) }
    let radios = displayedRadiosMO.prefix(appDelegate.player.maxSongsToAddOnce)
      .compactMap { Radio(managedObject: $0) }
    return PlayContext(
      name: sceneTitle ?? "",
      index: radios.isEmpty ? 0 : Int.random(in: 0 ..< radios.count),
      playables: radios
    )
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
    let radio = fetchedResultsController.getWrappedEntity(at: indexPath)
    cell.display(playable: radio, playContextCb: convertCellViewToPlayContext, rootView: self)
    return cell
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    0.0
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    nil
  }

  func convertIndexPathToPlayContext(radioIndexPath: IndexPath) -> PlayContext? {
    guard let radios = fetchedResultsController.getContextRadios()
    else { return nil }
    let selectedRadio = fetchedResultsController.getWrappedEntity(at: radioIndexPath)
    guard let playContextIndex = radios.firstIndex(of: selectedRadio) else { return nil }
    return PlayContext(name: sceneTitle ?? "", index: playContextIndex, playables: radios)
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell) else { return nil }
    return convertIndexPathToPlayContext(radioIndexPath: indexPath)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    guard let searchText = searchController.searchBar.text else { return }
    if !searchText.isEmpty {
      fetchedResultsController.search(searchText: searchText)
    } else {
      fetchedResultsController.showAllResults()
    }
    tableView.reloadData()
  }

  @objc
  func handleRefresh(refreshControl: UIRefreshControl) {
    guard appDelegate.storage.settings.isOnlineMode else {
      #if !targetEnvironment(macCatalyst)
        self.refreshControl?.endRefreshing()
      #endif
      return
    }
    Task { @MainActor in
      do {
        try await self.appDelegate.librarySyncer.syncRadios()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Radios Sync", error: error)
      }
      self.detailHeaderView?.refresh()
      self.updateSearchResults(for: self.searchController)
      #if !targetEnvironment(macCatalyst)
        self.refreshControl?.endRefreshing()
      #endif
    }
  }
}
