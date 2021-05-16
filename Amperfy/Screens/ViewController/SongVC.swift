import UIKit
import CoreData

class SongVC: SingleFetchedResultsTableViewController<SongMO> {

    private var fetchedResultsController: SongFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController = SongFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Songs\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: true)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        tableView.separatorStyle = .none
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Only search performes fetches in this view
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(song: song, rootView: self)
        return cell
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchSongs(searchText: searchText, libraryStorage: backgroundLibrary)
            }
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
            tableView.separatorStyle = .singleLine
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
            tableView.separatorStyle = .singleLine
        } else {
            fetchedResultsController.clearResults()
            tableView.separatorStyle = .none
        }
        tableView.reloadData()
    }
    
}

