import UIKit
import CoreData

class LatestSongsVC: SingleFetchedResultsTableViewController<SongMO> {

    private var fetchedResultsController: LatestSongsFetchedResultsController!
    private var actionButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController = LatestSongsFetchedResultsController(managedObjectContext: appDelegate.storage.context)
        fetchedResultsController.delegate = self
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        actionButton = UIBarButtonItem(title: "...", style: .plain, target: self, action: #selector(operateOnAll))
        navigationItem.rightBarButtonItem = actionButton
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

    @objc private func operateOnAll() {
        guard let fetchedObjects = self.fetchedResultsController.fetchedObjects else { return }
        let songs = fetchedObjects.compactMap{ Song(managedObject: $0) }
        
        let alert = UIAlertController(title: "Latest songs", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
            self.appDelegate.downloadManager.download(songs: songs)
        }))
        if songs.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                songs.forEach{ song in
                    self.appDelegate.persistentLibraryStorage.deleteCache(ofSong: song)
                }
                self.appDelegate.persistentLibraryStorage.saveContext()
                self.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Add all to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songsToAdd = songs
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.present(selectPlaylistNav, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "", onlyCachedSongs: (searchController.searchBar.selectedScopeButtonIndex == 1))
        tableView.reloadData()
    }
    
}

