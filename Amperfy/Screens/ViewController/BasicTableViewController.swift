import UIKit
import Foundation
import CoreData

class SingleFetchedResultsTableViewController<ResultType>: BasicTableViewController where ResultType : NSFetchRequestResult {
    
    private var singleFetchController: BasicFetchedResultsController<ResultType>?
    var singleFetchedResultsController: BasicFetchedResultsController<ResultType>? {
        set {
            singleFetchController = newValue
            singleFetchController?.delegate = self
        }
        get { return singleFetchController }
    }
    
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
        return singleFetchController?.sectionIndexTitles
    }

}

class BasicTableViewController: UITableViewController {
    
    var appDelegate: AppDelegate!
    let searchController = UISearchController(searchResultsController: nil)
    
    private static let changeCountToPerformeDataReload = 30
    var sectionChanges = false
    var rowsToInsert = [IndexPath]()
    var rowsToDelete = [IndexPath]()
    var rowsToUpdate = [IndexPath]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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

}

extension BasicTableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        sectionChanges = false
        rowsToInsert = [IndexPath]()
        rowsToDelete = [IndexPath]()
        rowsToUpdate = [IndexPath]()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let changeCount = rowsToInsert.count +
            rowsToDelete.count +
            rowsToUpdate.count
        
        if sectionChanges || (changeCount > Self.changeCountToPerformeDataReload) {
            tableView.reloadData()
        } else {
            tableView.beginUpdates()
            if !rowsToInsert.isEmpty {
                tableView.insertRows(at: rowsToInsert, with: .bottom)
            }
            if !rowsToDelete.isEmpty {
                tableView.deleteRows(at: rowsToDelete, with: .left)
            }
            if !rowsToUpdate.isEmpty {
                tableView.reloadRows(at: rowsToUpdate, with: .none)
            }
            tableView.endUpdates()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            rowsToInsert.append(newIndexPath!)
        case .delete:
            rowsToDelete.append(indexPath!)
        case .move:
            if indexPath! != newIndexPath! {
                rowsToInsert.append(newIndexPath!)
                rowsToDelete.append(indexPath!)
            } else {
                rowsToUpdate.append(indexPath!)
            }
        case .update:
            rowsToUpdate.append(indexPath!)
        @unknown default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        sectionChanges = true
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
