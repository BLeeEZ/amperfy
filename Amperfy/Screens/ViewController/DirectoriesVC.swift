import UIKit
import CoreData

class DirectoriesVC: BasicTableViewController {
    
    var directory: Directory!
    private var subdirectoriesFetchedResultsController: DirectorySubdirectoriesFetchedResultsController!
    private var songsFetchedResultsController: DirectorySongsFetchedResultsController!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.directories)
        
        subdirectoriesFetchedResultsController = DirectorySubdirectoriesFetchedResultsController(for: directory, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        subdirectoriesFetchedResultsController.delegate = self
        songsFetchedResultsController = DirectorySongsFetchedResultsController(for: directory, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        songsFetchedResultsController.delegate = self
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        configureSearchController(placeholder: "Directories and Songs", scopeButtonTitles: ["All", "Cached"])
        navigationItem.title = directory.name
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        swipeCallback = { (indexPath, completionHandler) in
            switch indexPath.section {
            case 1:
                let song = self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                completionHandler([song])
            default:
                completionHandler([])
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let directoryAsync = Directory(managedObject: context.object(with: self.directory.managedObject.objectID) as! DirectoryMO)
                syncer.sync(directory: directoryAsync, library: library)
            }
        }
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section == 1,
              let songs = songsFetchedResultsController.getContextSongs(onlyCachedSongs: appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(name: directory.name, index: playContextIndex, playables: songs)
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return subdirectoriesFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case 1:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
            let cellDirectory = subdirectoriesFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(directory: cellDirectory)
            return cell
        case 1:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return DirectoryTableCell.rowHeight
        case 1:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }
        return super.tableView(tableView, leadingSwipeActionsConfigurationForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }
        return super.tableView(tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0, let navController = navigationController else { return }

        let selectedDirectory = subdirectoriesFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
        let directoriesVC = DirectoriesVC.instantiateFromAppStoryboard()
        directoriesVC.directory = selectedDirectory
        navController.pushViewController(directoriesVC, animated: true)
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            subdirectoriesFetchedResultsController.search(searchText: searchText)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            subdirectoriesFetchedResultsController.search(searchText: searchText)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            subdirectoriesFetchedResultsController.showAllResults()
            songsFetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case subdirectoriesFetchedResultsController.fetchResultsController:
            section = 0
        case songsFetchedResultsController.fetchResultsController:
            section = 1
        default:
            return
        }
        
        super.applyChangesOfMultiRowType(determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }

}
