import UIKit
import CoreData

class PlaylistSelectorVC: SingleFetchedResultsTableViewController<PlaylistMO> {

    var songsToAdd: [Song]?
    
    private var fetchedResultsController: PlaylistSelectorFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlistSelector)
        
        fetchedResultsController = PlaylistSelectorFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Playlists\"", showSearchBarAtEnter: true)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight))
        if let newPlaylistTableHeaderView = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            syncer.syncDownPlaylistsWithoutSongs(libraryStorage: backgroundLibrary)
        }
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
        cell.display(playlist: playlist)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        if let songs = songsToAdd {
            playlist.append(songs: songs)
            appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundStorage = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let playlistAsync = playlist.getManagedObject(in: context, storage: backgroundStorage)
                let songsAsync = songs.compactMap {
                    Song(managedObject: context.object(with: $0.objectID) as! SongMO)
                }
                syncer.syncUpload(playlistToAddSongs: playlistAsync, songs: songsAsync, libraryStorage: backgroundStorage)
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
