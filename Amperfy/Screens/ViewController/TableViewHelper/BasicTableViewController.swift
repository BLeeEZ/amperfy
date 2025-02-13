//
//  BasicTableViewController.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 23.02.24.
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
import Foundation
import UIKit

extension UIViewController {
  func setNavBarTitle(title: String) {
    self.title = title
  }
}

// MARK: - TableViewPreviewInfo

public struct TableViewPreviewInfo: Codable {
  public var playableContainerIdentifier: PlayableContainerIdentifier?
  public var indexPath: IndexPath?

  static func create(fromIdentifier identifier: String) -> TableViewPreviewInfo? {
    guard let identifierData = identifier.data(using: .utf8),
          let tvIdentifier = try? JSONDecoder().decode(
            TableViewPreviewInfo.self,
            from: identifierData
          )
    else { return nil }
    return tvIdentifier
  }
}

public typealias ContainableAtIndexPathCallback = (IndexPath) -> PlayableContainable?
public typealias SwipeActionCallback = (
  IndexPath,
  _ completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> ()
)
  -> ()
public typealias PlayContextAtIndexPathCallback = (IndexPath) -> PlayContext?

// MARK: - SwipeDisplaySettings

struct SwipeDisplaySettings {
  var playContextTypeOfElements: PlayerMode = .music

  func isAllowedToDisplay(
    actionType: SwipeActionType,
    containable: PlayableContainable,
    isOfflineMode: Bool
  )
    -> Bool {
    switch playContextTypeOfElements {
    case .music:
      if actionType == .addToPlaylist,
         containable.playables.count == 1,
         containable.playables[0].isRadio {
        return false
      }
      if actionType == .insertPodcastQueue ||
        actionType == .appendPodcastQueue {
        return false
      }
    case .podcast:
      if actionType == .playShuffled ||
        actionType == .addToPlaylist ||
        actionType == .insertContextQueue ||
        actionType == .appendContextQueue ||
        actionType == .insertUserQueue ||
        actionType == .appendUserQueue {
        return false
      }
    }
    if isOfflineMode,
       actionType == .addToPlaylist || actionType == .download || actionType == .favorite {
      return false
    }
    if !containable.isFavoritable, actionType == .favorite {
      return false
    }
    return true
  }
}

// MARK: - BasicTableViewController

class BasicTableViewController: KeyCommandTableViewController {
  private static let swipeButtonColors: [UIColor] = [
    .defaultBlue,
    .systemOrange,
    .systemPurple,
    .systemGray,
  ]

  let searchController = UISearchController(searchResultsController: nil)

  var swipeDisplaySettings = SwipeDisplaySettings()
  var containableAtIndexPathCallback: ContainableAtIndexPathCallback?
  var playContextAtIndexPathCallback: PlayContextAtIndexPathCallback?
  var swipeCallback: SwipeActionCallback?
  var isEditLockedDueToActiveSwipe = false
  var isSingleCellEditingModeActive = false

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.keyboardDismissMode = .onDrag
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)

    if searchController.searchBar.scopeButtonTitles?.count ?? 0 > 1,
       appDelegate.storage.settings.isOfflineMode {
      searchController.searchBar.selectedScopeButtonIndex = 1
    } else {
      searchController.searchBar.selectedScopeButtonIndex = 0
    }
    updateSearchResults(for: searchController)
  }

  override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
    isSingleCellEditingModeActive = true
  }

  override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    isSingleCellEditingModeActive = false
  }

  override func tableView(
    _ tableView: UITableView,
    leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  )
    -> UISwipeActionsConfiguration? {
    guard let swipeCB = swipeCallback,
          let containableCB = containableAtIndexPathCallback,
          let containable = containableCB(indexPath)
    else { return UISwipeActionsConfiguration() }

    var createdActionsIndex = 0
    var actions = [UIContextualAction]()
    for actionType in appDelegate.storage.settings.swipeActionSettings.leading {
      if !swipeDisplaySettings.isAllowedToDisplay(
        actionType: actionType,
        containable: containable,
        isOfflineMode: appDelegate.storage.settings.isOfflineMode
      ) { continue }
      let buttonColor = Self.swipeButtonColors.element(at: createdActionsIndex) ?? Self
        .swipeButtonColors.last!
      actions.append(createSwipeAction(
        for: actionType,
        buttonColor: buttonColor,
        indexPath: indexPath,
        preCbContainable: containable,
        actionCallback: swipeCB
      ))
      createdActionsIndex += 1
    }
    return UISwipeActionsConfiguration(actions: actions)
  }

  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  )
    -> UISwipeActionsConfiguration? {
    // return nil here allows to display the "Delete" confirmation swipe action in edit mode (nil -> show default action -> delete is the default one)
    guard !(tableView.isEditing && !isSingleCellEditingModeActive) else { return nil }
    // this empty configuration ensures to only perform one "Delete" action at a time (no confirmation is displayed)
    guard !(tableView.isEditing && isSingleCellEditingModeActive)
    else { return UISwipeActionsConfiguration() }
    guard let swipeCB = swipeCallback,
          let containableCB = containableAtIndexPathCallback,
          let containable = containableCB(indexPath)
    else { return UISwipeActionsConfiguration() }
    var createdActionsIndex = 0
    var actions = [UIContextualAction]()
    for actionType in appDelegate.storage.settings.swipeActionSettings.trailing {
      if !swipeDisplaySettings.isAllowedToDisplay(
        actionType: actionType,
        containable: containable,
        isOfflineMode: appDelegate.storage.settings.isOfflineMode
      ) { continue }
      let buttonColor = Self.swipeButtonColors.element(at: createdActionsIndex) ?? Self
        .swipeButtonColors.last!
      actions.append(createSwipeAction(
        for: actionType,
        buttonColor: buttonColor,
        indexPath: indexPath,
        preCbContainable: containable,
        actionCallback: swipeCB
      ))
      createdActionsIndex += 1
    }
    return UISwipeActionsConfiguration(actions: actions)
  }

  func configureSearchController(
    placeholder: String?,
    scopeButtonTitles: [String]? = nil,
    showSearchBarAtEnter: Bool = false
  ) {
    searchController.searchResultsUpdater = self
    searchController.searchBar.autocapitalizationType = .none
    searchController.searchBar.scopeButtonTitles = scopeButtonTitles
    searchController.searchBar.placeholder = placeholder

    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = !showSearchBarAtEnter

    #if targetEnvironment(macCatalyst)
      if #available(iOS 16.0, *) {
        navigationItem.preferredSearchBarPlacement = .inline
      }
    #endif

    searchController.delegate = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.delegate = self // Monitor when the search button is tapped.
    definesPresentationContext = true
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
    contextMenuConfigurationForRowAt indexPath: IndexPath,
    point: CGPoint
  )
    -> UIContextMenuConfiguration? {
    guard let containableCB = containableAtIndexPathCallback,
          let containable = containableCB(indexPath)
    else { return nil }

    let identifier = NSString(string: TableViewPreviewInfo(
      playableContainerIdentifier: containable.containerIdentifier,
      indexPath: indexPath
    ).asJSONString())
    return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
      let vc = EntityPreviewVC()
      vc.display(container: containable, on: self)

      Task { @MainActor in
        do {
          try await containable.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Preview Sync", error: error)
        }
        vc.refresh()
      }
      return vc
    }) { suggestedActions in
      var playIndexCB: (() -> PlayContext?)?
      if let playContextAtIndexPathCP = self.playContextAtIndexPathCallback {
        playIndexCB = { playContextAtIndexPathCP(indexPath) }
      }
      return EntityPreviewActionBuilder(
        container: containable,
        on: self,
        playContextCb: playIndexCB
      ).createMenu()
    }
  }

  override func tableView(
    _ tableView: UITableView,
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionCommitAnimating
  ) {
    animator.addCompletion {
      if let identifier = configuration.identifier as? String,
         let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
         let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
         let container = self.appDelegate.storage.main.library
         .getContainer(identifier: containerIdentifier) {
        EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
      }
    }
  }

  func createSwipeAction(
    for actionType: SwipeActionType,
    buttonColor: UIColor,
    indexPath: IndexPath,
    preCbContainable: PlayableContainable,
    actionCallback: @escaping SwipeActionCallback
  )
    -> UIContextualAction {
    let action = UIContextualAction(
      style: .normal,
      title: actionType.displayName
    ) { action, view, completionHandler in
      Haptics.success.vibrate(isHapticsEnabled: self.appDelegate.storage.settings.isHapticsEnabled)
      actionCallback(indexPath) { actionContext in
        guard let actionContext = actionContext else { return }
        switch actionType {
        case .insertUserQueue:
          self.appDelegate.player
            .insertUserQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .appendUserQueue:
          self.appDelegate.player
            .appendUserQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .insertContextQueue:
          self.appDelegate.player
            .insertContextQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .appendContextQueue:
          self.appDelegate.player
            .appendContextQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .download:
          self.appDelegate.playableDownloadManager.download(objects: actionContext.playables)
        case .removeFromCache:
          let alert = UIAlertController(
            title: nil,
            message: "Are you sure to delete the cached file\(actionContext.playables.count > 1 ? "s" : "")?",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.appDelegate.playableDownloadManager
              .removeFinishedDownload(for: actionContext.playables)
            self.appDelegate.storage.main.library.deleteCache(of: actionContext.playables)
            self.appDelegate.storage.main.saveContext()
            if let cell = self.tableView.cellForRow(at: indexPath) as? PlayableTableCell {
              cell.refresh()
            }
          }))
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            // do nothing
          }))
          self.present(alert, animated: true, completion: nil)
        case .addToPlaylist:
          let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
          selectPlaylistVC.itemsToAdd = actionContext.playables.filterSongs()
          let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
          self.present(selectPlaylistNav, animated: true)
        case .play:
          self.appDelegate.player.play(context: actionContext.playContext)
        case .playShuffled:
          var playContext = actionContext.playContext
          if actionContext.playables.count <= 1 {
            playContext.isKeepIndexDuringShuffle = true
          }
          self.appDelegate.player.playShuffled(context: playContext)
        case .insertPodcastQueue:
          self.appDelegate.player
            .insertPodcastQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .appendPodcastQueue:
          self.appDelegate.player
            .appendPodcastQueue(
              playables: actionContext.playables
                .filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            )
        case .favorite:
          Task { @MainActor in
            do {
              try await actionContext.containable
                .remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
            } catch {
              self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
            }
            if let cell = self.tableView.cellForRow(at: indexPath) as? PlayableTableCell {
              cell.refresh()
            }
          }
        }
      }
      completionHandler(true)
    }
    action.backgroundColor = buttonColor
    if actionType == .favorite {
      action.image = preCbContainable.isFavorite ? UIImage.heartFill : UIImage.heartEmpty
    } else {
      action.image = actionType.image.withRenderingMode(.alwaysOriginal)
    }
    return action
  }
}

// MARK: UISearchResultsUpdating

extension BasicTableViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {}
}

// MARK: UISearchBarDelegate

extension BasicTableViewController: UISearchBarDelegate {
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    searchBar.resignFirstResponder()
  }

  func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
    updateSearchResults(for: searchController)
  }
}

// MARK: UISearchControllerDelegate

extension BasicTableViewController: UISearchControllerDelegate {}
