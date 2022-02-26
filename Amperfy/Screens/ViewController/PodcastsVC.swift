import UIKit
import CoreData

enum PodcastsShowType: Int {
    case podcasts = 0
    case episodesSortedByReleaseDate = 1
    
    static let defaultValue: PodcastsShowType = .podcasts
}

class PodcastsVC: BasicTableViewController {

    private var podcastsFetchedResultsController: PodcastFetchedResultsController!
    private var episodesFetchedResultsController: PodcastEpisodesReleaseDateFetchedResultsController!
    private var sortButton: UIBarButtonItem!
    private var showType: PodcastsShowType = .podcasts
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.podcasts)
        
        podcastsFetchedResultsController = PodcastFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        podcastsFetchedResultsController.delegate = self
        episodesFetchedResultsController = PodcastEpisodesReleaseDateFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        episodesFetchedResultsController.delegate = self

        configureSearchController(placeholder: "Search in \"Podcasts\"", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: PodcastEpisodeTableCell.typeName)

        sortButton = UIBarButtonItem(title: "Show", style: .plain, target: self, action: #selector(sortButtonPressed))
        navigationItem.rightBarButtonItem = sortButton
        
        swipeDisplaySettings.playContextTypeOfElements = .podcast
        swipeCallback = { (indexPath, completionHandler) in
            switch self.showType {
            case .podcasts:
                let podcast = self.podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
                podcast.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
                    completionHandler(SwipeActionContext(containable: podcast))
                }
            case .episodesSortedByReleaseDate:
                let episode = self.episodesFetchedResultsController.getWrappedEntity(at: indexPath)
                completionHandler(SwipeActionContext(containable: episode))
            }
        }
        
        showType = appDelegate.persistentStorage.settings.podcastsShowSetting
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncFromServer()
    }
    
    func syncFromServer() {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            switch self.showType {
            case .podcasts:
                appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    syncer.syncDownPodcastsWithoutEpisodes(library: syncLibrary)
                }
            case .episodesSortedByReleaseDate:
                appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    syncer.syncDownPodcastsWithoutEpisodes(library: syncLibrary)
                    let podcasts = syncLibrary.getPodcasts().filter{$0.remoteStatus == .available}
                    for podcast in podcasts {
                        podcast.fetchFromServer(inContext: context, syncer: syncer)
                    }
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.showType {
        case .podcasts:
            return podcastsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .episodesSortedByReleaseDate:
            return episodesFetchedResultsController.sections?[0].numberOfObjects ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.showType {
        case .podcasts:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let podcast = podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
            cell.display(container: podcast, rootView: self)
            return cell
        case .episodesSortedByReleaseDate:
            let cell: PodcastEpisodeTableCell = dequeueCell(for: tableView, at: indexPath)
            let episode = episodesFetchedResultsController.getWrappedEntity(at: indexPath)
            cell.display(episode: episode, rootView: self)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch self.showType {
        case .podcasts:
            return GenericTableCell.rowHeight
        case .episodesSortedByReleaseDate:
            return PodcastEpisodeTableCell.rowHeight
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch self.showType {
        case .podcasts:
            let podcast = podcastsFetchedResultsController.getWrappedEntity(at: indexPath)
            performSegue(withIdentifier: Segues.toPodcastDetail.rawValue, sender: podcast)
        case .episodesSortedByReleaseDate:
            break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPodcastDetail.rawValue {
            let vc = segue.destination as! PodcastDetailVC
            let podcast = sender as? Podcast
            vc.podcast = podcast
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        switch self.showType {
        case .podcasts:
            let searchText = searchController.searchBar.text ?? ""
            podcastsFetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1)
            tableView.reloadData()
        case .episodesSortedByReleaseDate:
            let searchText = searchController.searchBar.text ?? ""
            episodesFetchedResultsController.search(searchText: searchText, onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1)
            tableView.reloadData()
        }
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Podcasts", message: nil, preferredStyle: .actionSheet)

        if showType == .podcasts {
            alert.addAction(UIAlertAction(title: "Episodes sorted by release date", style: .default, handler: { _ in
                self.showType = .episodesSortedByReleaseDate
                self.appDelegate.persistentStorage.settings.podcastsShowSetting = .episodesSortedByReleaseDate
                self.syncFromServer()
                self.updateSearchResults(for: self.searchController)
            }))
        } else {
            alert.addAction(UIAlertAction(title: "Grouped by Podcast", style: .default, handler: { _ in
                self.showType = .podcasts
                self.appDelegate.persistentStorage.settings.podcastsShowSetting = .podcasts
                self.syncFromServer()
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }

}
