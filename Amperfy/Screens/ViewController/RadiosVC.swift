//
//  RadiosVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.12.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import CoreData
import AmperfyKit
import PromiseKit

class RadiosVC: SingleFetchedResultsTableViewController<RadioMO> {
    
    override var sceneTitle: String? {
        return "Radios"
    }

    private var fetchedResultsController: RadiosFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()

#if !targetEnvironment(macCatalyst)
        self.refreshControl = UIRefreshControl()
#endif

        appDelegate.userStatistics.visited(.radios)
        
        fetchedResultsController = RadiosFetchedResultsController(coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
        
        configureSearchController(placeholder: "Search in \"\(self.sceneTitle ?? "")\"", showSearchBarAtEnter: true)
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        tableView.estimatedRowHeight = PlayableTableCell.rowHeight

#if !targetEnvironment(macCatalyst)
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
#endif

        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        playContextAtIndexPathCallback = { (indexPath) in
            let entity = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            return PlayContext(containable: entity)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let radio = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            let playContext = self.convertIndexPathToPlayContext(radioIndexPath: indexPath)
            completionHandler(SwipeActionContext(containable: radio, playContext: playContext))
        }
        setNavBarTitle(title: sceneTitle ?? "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFromRemote()
    }
    
    func updateFromRemote() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        firstly {
            self.appDelegate.librarySyncer.syncRadios()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Radios Sync", error: error)
        }.finally {
            self.updateSearchResults(for: self.searchController)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        let radio = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playable: radio, playContextCb: self.convertCellViewToPlayContext, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func convertIndexPathToPlayContext(radioIndexPath: IndexPath) -> PlayContext? {
        let selectedRadio = self.fetchedResultsController.getWrappedEntity(at: radioIndexPath)
        return PlayContext(containable: selectedRadio)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        return convertIndexPathToPlayContext(radioIndexPath: indexPath)
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0 {
            fetchedResultsController.search(searchText: searchText)
        } else {
            fetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
#if !targetEnvironment(macCatalyst)
            self.refreshControl?.endRefreshing()
#endif
            return
        }
        firstly {
            self.appDelegate.librarySyncer.syncRadios()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Radios Sync", error: error)
        }.finally {
            self.updateSearchResults(for: self.searchController)
#if !targetEnvironment(macCatalyst)
            self.refreshControl?.endRefreshing()
#endif
        }
    }
    
}
