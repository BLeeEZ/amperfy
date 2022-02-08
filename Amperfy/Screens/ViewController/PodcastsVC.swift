import UIKit
import CoreData

class PodcastsVC: SingleFetchedResultsTableViewController<PodcastMO> {

    private var fetchedResultsController: PodcastFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.podcasts)
        
        fetchedResultsController = PodcastFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Podcasts\"", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: PodcastTableCell.typeName)
        tableView.rowHeight = PodcastTableCell.rowHeight
        
        swipeCallback = { (indexPath, completionHandler) in
            let podcast = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.fetchDetails(of: podcast) {
                completionHandler(SwipeActionContext(containable: podcast))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.syncDownPodcastsWithoutEpisodes(library: syncLibrary)
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PodcastTableCell = dequeueCell(for: tableView, at: indexPath)
        let podcast = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(podcast: podcast, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toPodcastDetail.rawValue, sender: genre)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPodcastDetail.rawValue {
            let vc = segue.destination as! PodcastDetailVC
            let podcast = sender as? Podcast
            vc.podcast = podcast
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1)
        tableView.reloadData()
    }

}
