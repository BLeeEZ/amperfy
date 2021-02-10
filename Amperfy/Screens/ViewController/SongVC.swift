import UIKit

class SongVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var songsAll: [Song]!
    var songsUnfiltered: [Song]!
    var songsFiltered: [Song]!
    var sections = [AlphabeticSection<Song>]()

    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        configureSearchController()
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        songsAll = appDelegate.library.getSongs().sortAlphabeticallyAscending()
        updateDataBasedOnScope()
        updateSearchResults(for: searchController)
    }
    
    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.scopeButtonTitles = ["All", "Cached"]

        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }
        
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self // Monitor when the search button is tapped.
        self.definesPresentationContext = true
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = sections[section]
        return section.sectionName
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CommonScreenOperations.tableSectionHeightLarge
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = self.sections[section]
        return section.entries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)

        let section = self.sections[indexPath.section]
        let song = section.entries[indexPath.row]
        
        cell.display(song: song, rootView: self)

        return cell
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var indexTitles = [String]()
        for section in sections {
            indexTitles.append(section.sectionName)
        }
        return indexTitles
    }
    
}

extension SongVC: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            songsFiltered = songsUnfiltered.filterBy(searchText: searchText)
        } else {
            songsFiltered = songsUnfiltered
        }
        sections = AlphabeticSection<Song>.group(songsFiltered)
        tableView.reloadData()
    }
    
}

extension SongVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateDataBasedOnScope()
        updateSearchResults(for: searchController)
    }
    
    func updateDataBasedOnScope() {
        switch searchController.searchBar.selectedScopeButtonIndex {
        case 1:
            songsUnfiltered = songsAll.filterCached()
        default:
            songsUnfiltered = songsAll
        }
    }
    
}

extension SongVC: UISearchControllerDelegate {
}
