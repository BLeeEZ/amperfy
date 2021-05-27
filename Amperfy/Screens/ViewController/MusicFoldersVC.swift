import UIKit
import CoreData

class MusicFoldersVC: SingleFetchedResultsTableViewController<MusicFolderMO> {
    
    private var fetchedResultsController: MusicFolderFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.musicFolders)
        
        fetchedResultsController = MusicFolderFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Directories\"")
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.rowHeight = DirectoryTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            syncer.syncMusicFolders(libraryStorage: library)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
        let musicFolder = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(folder: musicFolder)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let musicFolder = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: musicFolder)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toDirectories.rawValue {
            let vc = segue.destination as! IndexesVC
            let musicFolder = sender as? MusicFolder
            vc.musicFolder = musicFolder
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "")
        tableView.reloadData()
    }

}
