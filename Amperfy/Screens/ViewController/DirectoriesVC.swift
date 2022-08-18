//
//  DirectoriesVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.05.21.
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
import CoreData
import AmperfyKit

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
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        configureSearchController(placeholder: "Directories and Songs", scopeButtonTitles: ["All", "Cached"])
        navigationItem.title = directory.name
        
        containableAtIndexPathCallback = { (indexPath) in
            switch indexPath.section {
            case 1:
                let songIndexPath = IndexPath(row: indexPath.row, section: 0)
                return self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
            default:
                return nil
            }
        }
        swipeCallback = { (indexPath, completionHandler) in
            switch indexPath.section {
            case 1:
                let songIndexPath = IndexPath(row: indexPath.row, section: 0)
                let song = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
                let playContext = self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
                completionHandler(SwipeActionContext(containable: song, playContext: playContext))
            default:
                completionHandler(nil)
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
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(name: directory.name, index: playContextIndex, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section == 1
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
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
        
        super.applyChangesOfMultiRowType(controller, didChange: anObject, determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }

}
