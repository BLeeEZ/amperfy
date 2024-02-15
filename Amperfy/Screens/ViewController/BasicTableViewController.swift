//
//  BasicTableViewController.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 16.04.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

class SingleFetchedResultsTableViewController<ResultType>: BasicTableViewController where ResultType : NSFetchRequestResult {
    
    private var singleFetchController: BasicFetchedResultsController<ResultType>?
    var singleFetchedResultsController: BasicFetchedResultsController<ResultType>? {
        set {
            singleFetchController = newValue
            singleFetchController?.delegate = self
        }
        get { return singleFetchController }
    }
    
    var isIndexTitelsHidden = false
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return singleFetchController?.numberOfSections ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return singleFetchController?.titleForHeader(inSection: section)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return singleFetchController?.numberOfRows(inSection: section) ?? 0
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return isIndexTitelsHidden ? nil : singleFetchController?.sectionIndexTitles
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return singleFetchController?.section(forSectionIndexTitle: title, at: index) ?? 0
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

extension BasicTableViewController {
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

class BasicTableViewController: UITableViewController {
    
    private static let swipeButtonColors: [UIColor] = [.defaultBlue, .systemOrange, .systemPurple, .systemGray]
    
    var appDelegate: AppDelegate!
    let searchController = UISearchController(searchResultsController: nil)
    
    var isRefreshAnimationOff = false
    var swipeDisplaySettings = SwipeDisplaySettings()
    var containableAtIndexPathCallback: ContainableAtIndexPathCallback?
    var playContextAtIndexPathCallback: PlayContextAtIndexPathCallback?
    var swipeCallback: SwipeActionCallback?
    private var isEditLockedDueToActiveSwipe = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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
    
    override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        isEditLockedDueToActiveSwipe = true
    }
    
    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        isEditLockedDueToActiveSwipe = false
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
        
        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = !showSearchBarAtEnter
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }
        
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
        
        let identifier = NSString(string: containable.containerIdentifierString)
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
            if let identifierString = configuration.identifier as? String,
               let container = PlayableContainerIdentifier.getContainer(library: self.appDelegate.storage.main.library, containerIdentifierString: identifierString) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        }
    }
    
}

extension BasicTableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        self.applyChangesFromFetchedResultsController(at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func applyChangesOfMultiRowType(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, determinedSection section: Int, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var adjustedIndexPath: IndexPath?
        if let indexPath = indexPath {
            adjustedIndexPath = IndexPath(row: indexPath.row, section: section)
        }
        var adjustedNewIndexPath: IndexPath?
        if let newIndexPath = newIndexPath {
            adjustedNewIndexPath = IndexPath(row: newIndexPath.row, section: section)
        }
        self.applyChangesFromFetchedResultsController(at: adjustedIndexPath, for: type, newIndexPath: adjustedNewIndexPath)
    }
    
    private func applyChangesFromFetchedResultsController(at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: isRefreshAnimationOff ? .none : .bottom)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: isRefreshAnimationOff ? .none : .left)
        case .move:
            if indexPath! != newIndexPath!, !isRefreshAnimationOff {
                tableView.insertRows(at: [newIndexPath!], with: .bottom)
                tableView.deleteRows(at: [indexPath!], with: .left)
            } else {
                tableView.insertRows(at: [newIndexPath!], with: .none)
                tableView.deleteRows(at: [indexPath!], with: .none)
            }
        case .update:
            if !isEditLockedDueToActiveSwipe {
                tableView.reloadRows(at: [indexPath!], with: .none)
            }
        @unknown default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let indexSet = IndexSet(integer: sectionIndex)
        switch type {
        case .insert:
            tableView.insertSections(indexSet, with: .automatic)
        case .delete:
            tableView.deleteSections(indexSet, with: .automatic)
        default:
            break
        }
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
