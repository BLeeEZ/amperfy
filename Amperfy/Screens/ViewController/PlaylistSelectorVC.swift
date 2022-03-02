import UIKit
import CoreData

class PlaylistSelectorVC: SingleFetchedResultsTableViewController<PlaylistMO> {

    var itemsToAdd: [AbstractPlayable]?
    
    private var fetchedResultsController: PlaylistSelectorFetchedResultsController!
    private var sortType: PlaylistSortType = .name
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlistSelector)
        
        change(sortType: appDelegate.persistentStorage.settings.playlistsSortSetting)
        fetchedResultsController = PlaylistSelectorFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: appDelegate.persistentStorage.settings.playlistsSortSetting, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Playlists\"", showSearchBarAtEnter: true)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight))
        if let newPlaylistTableHeaderView = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
        }
    }
    
    func change(sortType: PlaylistSortType) {
        self.sortType = sortType
        // sortType will not be saved permanently. This behaviour differs from PlaylistsVC
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = PlaylistSelectorFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: sortType, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.syncDownPlaylistsWithoutSongs(library: syncLibrary)
            }
        }
    }
    
    @IBAction func sortButtonPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Playlists sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastPlayed {
            alert.addAction(UIAlertAction(title: "Sort by last time played", style: .default, handler: { _ in
                self.change(sortType: .lastPlayed)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastChanged {
            alert.addAction(UIAlertAction(title: "Sort by last time changed", style: .default, handler: { _ in
                self.change(sortType: .lastChanged)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss()
    }
    
    private func dismiss() {
        searchController.dismiss(animated: false, completion: nil)
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playlist: playlist, rootView: nil)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        if let items = itemsToAdd {
            playlist.append(playables: items)
            if appDelegate.persistentStorage.settings.isOnlineMode {
                appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    let playlistAsync = playlist.getManagedObject(in: context, library: syncLibrary)
                    let songsAsync = items.compactMap{ context.object(with: $0.objectID) as? SongMO }.compactMap{ Song(managedObject: $0) }
                    syncer.syncUpload(playlistToAddSongs: playlistAsync, songs: songsAsync, library: syncLibrary)
                }
            }
        }
        dismiss()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPlaylistDetail.rawValue {
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        }
    }

    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        fetchedResultsController.search(searchText: searchText)
        tableView.reloadData()
    }
    
}
