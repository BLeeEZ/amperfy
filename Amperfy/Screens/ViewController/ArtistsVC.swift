import UIKit
import CoreData

class ArtistsVC: SingleFetchedResultsTableViewController<ArtistMO> {

    private var fetchedResultsController: ArtistFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.artists)
        
        fetchedResultsController = ArtistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Artists\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.rowHeight = ArtistTableCell.rowHeight
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        swipeCallback = { (indexPath, completionHandler) in
            let artist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.fetchDetails(of: artist) {
                completionHandler(SwipeActionContext(containable: artist))
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
        let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(artist: artist, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchArtists(searchText: searchText, library: backgroundLibrary)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1)
        tableView.reloadData()
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            if self.appDelegate.persistentStorage.settings.isOnlineMode {
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.syncLatestLibraryElements(library: syncLibrary)
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                }
            } else {
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                }
            }

        }
    }

}

