//
//  PodcastDetailVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AmperfyKit
import PromiseKit

class PodcastDetailVC: SingleFetchedResultsTableViewController<PodcastEpisodeMO> {

    var podcast: Podcast!
    var episodeToScrollTo: PodcastEpisode?
    private var fetchedResultsController: PodcastEpisodesFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var detailOperationsView: GenericDetailTableHeader?
    private var descriptionView: FullWidthDescriptionView?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.podcastDetail)
        fetchedResultsController = PodcastEpisodesFetchedResultsController(forPodcast: podcast, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
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
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let episode = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            completionHandler(SwipeActionContext(containable: episode))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        firstly {
            podcast.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
        }.finally {
            self.detailOperationsView?.refresh()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defer { episodeToScrollTo = nil }
        guard let episodeToScrollTo = episodeToScrollTo,
              let indexPath = fetchedResultsController.fetchResultsController.indexPath(forObject: episodeToScrollTo.managedObject)
        else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
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
        firstly {
            self.appDelegate.librarySyncer.sync(podcast: self.podcast)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
        }.finally {
            self.detailOperationsView?.refresh()
            self.tableView.visibleCells.forEach{ ($0 as! PodcastEpisodeTableCell).refresh() }
            self.refreshControl?.endRefreshing()
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
