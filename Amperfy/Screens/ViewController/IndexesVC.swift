import UIKit
import CoreData

class IndexesVC: SingleFetchedResultsTableViewController<DirectoryMO> {
    
    var musicFolder: MusicFolder!
    private var fetchedResultsController: MusicFolderDirectoriesFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.indexes)
        
        fetchedResultsController = MusicFolderDirectoriesFetchedResultsController(for: musicFolder, managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        navigationItem.title = musicFolder.name
        configureSearchController(placeholder: "Search in \"Directories\"")
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.rowHeight = DirectoryTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let musicFolderAsync = MusicFolder(managedObject: context.object(with: self.musicFolder.managedObject.objectID) as! MusicFolderMO)
            syncer.syncIndexes(musicFolder: musicFolderAsync, libraryStorage: library)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
        let directory = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(directory: directory)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let directory = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: directory)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toDirectories.rawValue {
            let vc = segue.destination as! DirectoriesVC
            let directory = sender as! Directory
            vc.directory = directory
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "")
        tableView.reloadData()
    }

}
