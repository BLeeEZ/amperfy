import UIKit
import CoreData

class SongsVC: SingleFetchedResultsTableViewController<SongMO> {

    private var fetchedResultsController: SongFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.songs)
        
        fetchedResultsController = SongFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Songs\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(title: "\(CommonString.threeMiddleDots)", style: .plain, target: self, action: #selector(optionsPressed))
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            navigationItem.rightBarButtonItem = optionsButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
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
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchSongs(searchText: searchText, library: backgroundLibrary)
            }
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            fetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    @objc private func optionsPressed() {
        let alert = UIAlertController(title: "Songs", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Play random songs", style: .default, handler: { _ in
            self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let randomSongsPlaylist = syncLibrary.createPlaylist()
                syncer.requestRandomSongs(playlist: randomSongsPlaylist, count: 100, library: syncLibrary)
                DispatchQueue.main.async {
                    let playlistMain = randomSongsPlaylist.getManagedObject(in: self.appDelegate.persistentStorage.context, library: self.appDelegate.library)
                    self.appDelegate.player.cleanPlaylist()
                    self.appDelegate.player.addToPlaylist(playables: playlistMain.playables)
                    self.appDelegate.player.play()
                    self.appDelegate.library.deletePlaylist(playlistMain)
                    self.appDelegate.library.saveContext()
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
}

