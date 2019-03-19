import UIKit

class PlaylistsVC: UITableViewController {

    var appDelegate: AppDelegate!
    var playlists = [Playlist]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        self.refreshControl?.addTarget(self, action: #selector(PlaylistsVC.handleRefresh), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        playlists = appDelegate.library.getPlaylists().sortAlphabeticallyAscending()
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        
        let playlist = playlists[indexPath.row]
        cell.display(playlist: playlist)
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = playlists[indexPath.row]
        performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let playlist = playlists[indexPath.row]
            playlists.remove(at: indexPath.row)
            appDelegate.persistentLibraryStorage.deletePlaylist(playlist)
            appDelegate.persistentLibraryStorage.saveContext()
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPlaylistDetail.rawValue {
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        }
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let storage = LibraryStorage(context: context)
            syncer.syncDownPlaylistsWithoutSongs(libraryStorage: storage)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playlists = self.appDelegate.library.getPlaylists()
                self.tableView.reloadData()
                refreshControl.endRefreshing()
            }
        }
    }
    
}
