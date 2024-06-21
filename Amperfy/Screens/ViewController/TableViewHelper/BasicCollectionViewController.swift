//
//  BasicCollectionViewController.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import CoreData
import AmperfyKit

class BasicCollectionViewController: UICollectionViewController {
    
    let searchController = UISearchController(searchResultsController: nil)
    
    var containableAtIndexPathCallback: ContainableAtIndexPathCallback?
    var playContextAtIndexPathCallback: PlayContextAtIndexPathCallback?
    var isIndexTitelsHidden = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.keyboardDismissMode = .onDrag
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
    
    override func collectionView(_ collectionView: UICollectionView,
                                 contextMenuConfigurationForItemAt indexPath: IndexPath,
                                 point: CGPoint) -> UIContextMenuConfiguration? {
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
    
    override func collectionView(_ collectionView: UICollectionView,
                                 willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                                 animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let identifier = configuration.identifier as? String,
               let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
               let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
               let container = self.appDelegate.storage.main.library.getContainer(identifier: containerIdentifier) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        }
    }
    
}

extension BasicCollectionViewController: UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate {
    
    func updateSearchResults(for searchController: UISearchController) {
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
    
}

class SingleSnapshotFetchedResultsCollectionViewController<ResultType>:
    BasicCollectionViewController,
    NSFetchedResultsControllerDelegate where ResultType : NSFetchRequestResult {
    
    var diffableDataSource: BasicUICollectionViewDiffableDataSource?
    var snapshotDidChange: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// Store the data source in an instance property to make sure it's retained.
        self.diffableDataSource = createDiffableDataSource()
        /// Assign the data source to your collection view.
        collectionView.dataSource = diffableDataSource
    }
    
    /// need to be overriden in child class
    func createDiffableDataSource() -> BasicUICollectionViewDiffableDataSource {
        fatalError("Should have been overriden in child class")
    }
    
    /// This will override the NSFetchedResultsController handling of the super class -> Only use snapshots
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        guard let dataSource = collectionView?.dataSource as? UICollectionViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }
        var snapshot = snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        let currentSnapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>

        let reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers.compactMap { itemIdentifier in
            guard let currentIndex = currentSnapshot.indexOfItem(itemIdentifier), let index = snapshot.indexOfItem(itemIdentifier), index == currentIndex else {
                return nil
            }
            guard let existingObject = try? controller.managedObjectContext.existingObject(with: itemIdentifier), existingObject.isUpdated else { return nil }
            return itemIdentifier
        }
        snapshot.reconfigureItems(reloadIdentifiers)
        
        dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: false)
        self.snapshotDidChange?()
    }
    
}
