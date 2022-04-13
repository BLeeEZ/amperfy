import UIKit
import CoreData

class ArtistsVC: SingleFetchedResultsTableViewController<ArtistMO> {

    private var fetchedResultsController: ArtistFetchedResultsController!
    private var filterButton: UIBarButtonItem!
    private var displayFilter: DisplayCategoryFilter = .all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.artists)
        
        fetchedResultsController = ArtistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Artists\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.rowHeight = GenericTableCell.rowHeight

        filterButton = UIBarButtonItem(image: UIImage.filter, style: .plain, target: self, action: #selector(filterButtonPressed))
        navigationItem.rightBarButtonItem = filterButton
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let artist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            artist.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
                completionHandler(SwipeActionContext(containable: artist))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFilterButton()
    }
    
    func updateFilterButton() {
        filterButton.image = displayFilter == .all ? UIImage.filter : UIImage.filterActive
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
        let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(container: artist, rootView: self)
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
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        tableView.reloadData()
    }
    
    @objc private func filterButtonPressed() {
        let alert = UIAlertController(title: "Artists filter", message: nil, preferredStyle: .actionSheet)
        
        if displayFilter != .favorites {
            alert.addAction(UIAlertAction(title: "Show favorites", image: UIImage.heartFill, style: .default, handler: { _ in
                self.displayFilter = .favorites
                self.updateFilterButton()
                self.updateSearchResults(for: self.searchController)
                if self.appDelegate.persistentStorage.settings.isOnlineMode {
                    self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                        let syncLibrary = LibraryStorage(context: context)
                        let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                        syncer.syncFavoriteLibraryElements(library: syncLibrary)
                        DispatchQueue.main.async {
                            self.updateSearchResults(for: self.searchController)
                        }
                    }
                }
            }))
        }
        if displayFilter != .all {
            alert.addAction(UIAlertAction(title: "Show all", style: .default, handler: { _ in
                self.displayFilter = .all
                self.updateFilterButton()
                self.updateSearchResults(for: self.searchController)
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
                let autoDownloadSyncer = AutoDownloadLibrarySyncer(persistentStorage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
                autoDownloadSyncer.syncLatestLibraryElements(context: context)
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

