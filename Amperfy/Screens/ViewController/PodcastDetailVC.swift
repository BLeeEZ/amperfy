import UIKit

class PodcastDetailVC: SingleFetchedResultsTableViewController<PodcastEpisodeMO> {

    var podcast: Podcast!
    private var fetchedResultsController: PodcastEpisodesFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var detailOperationsView: GenericDetailTableHeader?
    private var descriptionView: FullWidthDescriptionView?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.podcastDetail)
        fetchedResultsController = PodcastEpisodesFetchedResultsController(forPodcast: podcast, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Podcast\"", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: PodcastEpisodeTableCell.typeName)
        tableView.rowHeight = PodcastEpisodeTableCell.rowHeight

        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight + FullWidthDescriptionView.frameHeight))
        if let genericDetailTableHeaderView = ViewBuilder<GenericDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight)) {
            genericDetailTableHeaderView.prepare(toWorkOn: podcast, rootView: self)
            tableView.tableHeaderView?.addSubview(genericDetailTableHeaderView)
            detailOperationsView = genericDetailTableHeaderView
        }
        if let fullWidthDescriptionView = ViewBuilder<FullWidthDescriptionView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: GenericDetailTableHeader.frameHeight, width: view.bounds.size.width, height: FullWidthDescriptionView.frameHeight)) {
            fullWidthDescriptionView.descriptionLabel.text = podcast.depiction
            tableView.tableHeaderView?.addSubview(fullWidthDescriptionView)
            descriptionView = fullWidthDescriptionView
        }
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
        navigationItem.rightBarButtonItem = optionsButton
        
        swipeDisplaySettings.playContextTypeOfElements = .podcast
        swipeCallback = { (indexPath, completionHandler) in
            let episode = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            completionHandler(SwipeActionContext(containable: episode))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        podcast.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
            self.detailOperationsView?.refresh()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PodcastEpisodeTableCell = dequeueCell(for: tableView, at: indexPath)
        let episode = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(episode: episode, rootView: self)
        return cell
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "", onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1 )
        tableView.reloadData()
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let podcastAsync = Podcast(managedObject: context.object(with: self.podcast.managedObject.objectID) as! PodcastMO)
            syncer.sync(podcast: podcastAsync, library: library)
            DispatchQueue.main.async {
                self.detailOperationsView?.refresh()
                self.tableView.visibleCells.forEach{ ($0 as! PodcastEpisodeTableCell).refresh() }
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    @objc private func optionsPressed() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let podcast = self.podcast else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: podcast, on: self)
        present(detailVC, animated: true)
    }
    
}
