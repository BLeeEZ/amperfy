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

class BasicCollectionViewController: UICollectionViewController {
    
    var appDelegate: AppDelegate!
    let searchController = UISearchController(searchResultsController: nil)
    var blockOperations: [BlockOperation] = []
    var isIndexTitelsHidden = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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
    
}

extension BasicCollectionViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations.removeAll()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({
             self.blockOperations.forEach { $0.start() }
         }, completion: { finished in
             self.blockOperations.removeAll(keepingCapacity: false)
         })
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {

        let op: BlockOperation
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            op = BlockOperation { self.collectionView.insertItems(at: [newIndexPath]) }
        case .delete:
            guard let indexPath = indexPath else { return }
            op = BlockOperation { self.collectionView.deleteItems(at: [indexPath]) }
        case .move:
            guard let indexPath = indexPath,  let newIndexPath = newIndexPath else { return }
            op = BlockOperation { self.collectionView.moveItem(at: indexPath, to: newIndexPath) }
        case .update:
            guard let indexPath = indexPath else { return }
            op = BlockOperation { self.collectionView.reloadItems(at: [indexPath]) }
        @unknown default:
            fatalError()
        }

        blockOperations.append(op)
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
