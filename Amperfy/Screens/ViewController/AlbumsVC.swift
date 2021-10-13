import UIKit
import CoreData

class AlbumsVC: SingleFetchedResultsTableViewController<AlbumMO> {

    private var fetchedResultsController: AlbumFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var displayFilter: DisplayCategoryFilter = .all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albums)
        
        fetchedResultsController = AlbumFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Albums\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.rowHeight = AlbumTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(title: "\(CommonString.threeMiddleDots)", style: .plain, target: self, action: #selector(optionsPressed))
        navigationItem.rightBarButtonItem = optionsButton
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(album: album)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchAlbums(searchText: searchText, library: backgroundLibrary)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        tableView.reloadData()
    }
    
    
    @objc private func optionsPressed() {
        let alert = UIAlertController(title: "Albums", message: nil, preferredStyle: .actionSheet)

        if displayFilter == .recentlyAdded {
            alert.addAction(UIAlertAction(title: "Show all", style: .default, handler: { _ in
                self.displayFilter = .all
                self.updateSearchResults(for: self.searchController)
            }))
        } else {
            alert.addAction(UIAlertAction(title: "Show recently added", style: .default, handler: { _ in
                self.displayFilter = .recentlyAdded
                if self.appDelegate.persistentStorage.settings.isOnlineMode {
                    self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                        let syncLibrary = LibraryStorage(context: context)
                        let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                        syncer.syncLatestLibraryElements(library: syncLibrary)
                        DispatchQueue.main.async {
                            self.updateSearchResults(for: self.searchController)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updateSearchResults(for: self.searchController)
                    }
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
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

