import UIKit
import CoreData

class GenresVC: SingleFetchedResultsTableViewController<GenreMO> {

    private var fetchedResultsController: GenreFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController = GenreFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Genres\"")
        tableView.register(nibName: GenreTableCell.typeName)
        tableView.rowHeight = GenreTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GenreTableCell = dequeueCell(for: tableView, at: indexPath)
        let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(genre: genre)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let genre = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toGenreDetail.rawValue, sender: genre)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toGenreDetail.rawValue {
            let vc = segue.destination as! GenreDetailVC
            let genre = sender as? Genre
            vc.genre = genre
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "")
        tableView.reloadData()
    }

}

