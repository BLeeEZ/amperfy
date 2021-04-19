import UIKit
import CoreData

class SongVC: SingleFetchedResultsTableViewController<SongMO> {

    private var fetchedResultsController: SongFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController = SongFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Songs\"", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(song: song, rootView: self)
        return cell
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "", onlyCachedSongs: (searchController.searchBar.selectedScopeButtonIndex == 1))
        tableView.reloadData()
    }
    
}

