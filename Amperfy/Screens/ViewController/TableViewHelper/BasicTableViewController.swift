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

import UIKit
import Foundation
import CoreData
import AmperfyKit
import PromiseKit

public struct TableViewPreviewInfo: Codable {
    public var playableContainerIdentifier: PlayableContainerIdentifier?
    public var indexPath: IndexPath?
    
    static func create(fromIdentifier identifier: String) -> TableViewPreviewInfo? {
        guard let identifierData = identifier.data(using: .utf8),
              let tvIdentifier = try? JSONDecoder().decode(TableViewPreviewInfo.self, from: identifierData)
        else { return nil }
        return tvIdentifier
    }
}

public typealias ContainableAtIndexPathCallback = (IndexPath) -> PlayableContainable?
public typealias SwipeActionCallback = (IndexPath, _ completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> Void ) -> Void
public typealias PlayContextAtIndexPathCallback = (IndexPath) -> PlayContext?

struct SwipeDisplaySettings {
    var playContextTypeOfElements: PlayerMode = .music
    
    func isAllowedToDisplay(actionType: SwipeActionType, containable: PlayableContainable, isOfflineMode: Bool) -> Bool {
        switch playContextTypeOfElements {
        case .music:
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
        if isOfflineMode, actionType == .addToPlaylist || actionType == .download || actionType == .favorite {
            return false
        }
        if !containable.isFavoritable, actionType == .favorite {
            return false
        }
        return true
    }
}

class BasicTableViewController: UITableViewController {
    
    private static let swipeButtonColors: [UIColor] = [.defaultBlue, .systemOrange, .systemPurple, .systemGray]
    
    let searchController = UISearchController(searchResultsController: nil)
    
    var swipeDisplaySettings = SwipeDisplaySettings()
    var containableAtIndexPathCallback: ContainableAtIndexPathCallback?
    var playContextAtIndexPathCallback: PlayContextAtIndexPathCallback?
    var swipeCallback: SwipeActionCallback?
    var isEditLockedDueToActiveSwipe = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.keyboardDismissMode = .onDrag
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if searchController.searchBar.scopeButtonTitles?.count ?? 0 > 1, appDelegate.storage.settings.isOfflineMode {
            searchController.searchBar.selectedScopeButtonIndex = 1
        } else {
            searchController.searchBar.selectedScopeButtonIndex = 0
        }
        updateSearchResults(for: searchController)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let swipeCB = swipeCallback,
              let containableCB = containableAtIndexPathCallback,
              let containable = containableCB(indexPath)
        else { return nil }
        
        var createdActionsIndex = 0
        var actions = [UIContextualAction]()
        for actionType in appDelegate.storage.settings.swipeActionSettings.leading {
            if !swipeDisplaySettings.isAllowedToDisplay(actionType: actionType, containable: containable, isOfflineMode: appDelegate.storage.settings.isOfflineMode) { continue }
            let buttonColor = Self.swipeButtonColors.element(at: createdActionsIndex) ?? Self.swipeButtonColors.last!
            actions.append(createSwipeAction(for: actionType, buttonColor: buttonColor, indexPath: indexPath, preCbContainable: containable, actionCallback: swipeCB))
            createdActionsIndex += 1
        }
        return UISwipeActionsConfiguration(actions: actions)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !tableView.isEditing else { return nil }
        guard let swipeCB = swipeCallback,
              let containableCB = containableAtIndexPathCallback,
              let containable = containableCB(indexPath)
        else { return nil }
        var createdActionsIndex = 0
        var actions = [UIContextualAction]()
        for actionType in appDelegate.storage.settings.swipeActionSettings.trailing {
            if !swipeDisplaySettings.isAllowedToDisplay(actionType: actionType, containable: containable, isOfflineMode: appDelegate.storage.settings.isOfflineMode) { continue }
            let buttonColor = Self.swipeButtonColors.element(at: createdActionsIndex) ?? Self.swipeButtonColors.last!
            actions.append(createSwipeAction(for: actionType, buttonColor: buttonColor, indexPath: indexPath, preCbContainable: containable, actionCallback: swipeCB))
            createdActionsIndex += 1
        }
        return UISwipeActionsConfiguration(actions: actions)
    }

    func configureSearchController(placeholder: String?, scopeButtonTitles: [String]? = nil, showSearchBarAtEnter: Bool = false) {
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.scopeButtonTitles = scopeButtonTitles
        searchController.searchBar.placeholder = placeholder
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = !showSearchBarAtEnter
        
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self // Monitor when the search button is tapped.
        self.definesPresentationContext = true
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let containableCB = containableAtIndexPathCallback,
              let containable = containableCB(indexPath)
        else { return nil }
        
        let identifier = NSString(string: TableViewPreviewInfo(playableContainerIdentifier: containable.containerIdentifier, indexPath: indexPath).asJSONString())
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            let vc = EntityPreviewVC()
            vc.display(container: containable, on: self)
            containable.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            .catch { error in
                self.appDelegate.eventLogger.report(topic: "Preview Sync", error: error)
            }.finally {
                vc.refresh()
            }
            return vc
        }) { suggestedActions in
            var playIndexCB : (() -> PlayContext?)?
            if let playContextAtIndexPathCP = self.playContextAtIndexPathCallback {
                playIndexCB = { playContextAtIndexPathCP(indexPath) }
            }
            return EntityPreviewActionBuilder(container: containable, on: self, playContextCb: playIndexCB).createMenu()
        }
    }
    
    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let identifier = configuration.identifier as? String,
               let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
               let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
               let container = self.appDelegate.storage.main.library.getContainer(identifier: containerIdentifier) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        }
    }

    func createSwipeAction(for actionType: SwipeActionType, buttonColor: UIColor, indexPath: IndexPath, preCbContainable: PlayableContainable, actionCallback: @escaping SwipeActionCallback) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: actionType.displayName) { (action, view, completionHandler) in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            actionCallback(indexPath) { actionContext in
                guard let actionContext = actionContext else { return }
                switch actionType {
                case .insertUserQueue:
                    self.appDelegate.player.insertUserQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .appendUserQueue:
                    self.appDelegate.player.appendUserQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .insertContextQueue:
                    self.appDelegate.player.insertContextQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .appendContextQueue:
                    self.appDelegate.player.appendContextQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .download:
                    self.appDelegate.playableDownloadManager.download(objects: actionContext.playables)
                case .removeFromCache:
                    self.appDelegate.playableDownloadManager.removeFinishedDownload(for: actionContext.playables)
                    self.appDelegate.storage.main.library.deleteCache(of: actionContext.playables)
                    self.appDelegate.storage.main.saveContext()
                case .addToPlaylist:
                    let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                    selectPlaylistVC.itemsToAdd = actionContext.playables
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
                    self.appDelegate.player.insertPodcastQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .appendPodcastQueue:
                    self.appDelegate.player.appendPodcastQueue(playables: actionContext.playables.filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode))
                case .favorite:
                    firstly {
                        actionContext.containable.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
                    }.catch { error in
                        self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
                    }
                }
            }
            completionHandler(true)
        }
        action.backgroundColor = buttonColor
        if actionType == .favorite {
            action.image = preCbContainable.isFavorite ? UIImage.heartFill : UIImage.heartEmpty
        } else {
            action.image = actionType.image
        }
        return action
    }

}


extension BasicTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        
    }
    
}

extension BasicTableViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
    
}

extension BasicTableViewController: UISearchControllerDelegate {
}

