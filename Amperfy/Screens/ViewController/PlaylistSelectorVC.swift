//
//  PlaylistSelectorVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

class PlaylistSelectorVC: SingleFetchedResultsTableViewController<PlaylistMO> {

    var itemsToAdd: [AbstractPlayable]?
    
    private var fetchedResultsController: PlaylistSelectorFetchedResultsController!
    private var sortType: PlaylistSortType = .name
    
    @IBOutlet weak var sortBarButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlistSelector)
        
        change(sortType: appDelegate.storage.settings.playlistsSortSetting)
        
        configureSearchController(placeholder: "Search in \"Playlists\"", showSearchBarAtEnter: true)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        sortBarButton.image = UIImage.sort

        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight))
        if let newPlaylistTableHeaderView = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
        }
    }
    
    func change(sortType: PlaylistSortType) {
        self.sortType = sortType
        // sortType will not be saved permanently. This behaviour differs from PlaylistsVC
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = PlaylistSelectorFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: sortType == .name)
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard appDelegate.storage.settings.isOnlineMode else { return }
        firstly {
            self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
        }
    }
    
    @IBAction func sortBarButtonPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Playlists sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastPlayed {
            alert.addAction(UIAlertAction(title: "Sort by last time played", style: .default, handler: { _ in
                self.change(sortType: .lastPlayed)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastChanged {
            alert.addAction(UIAlertAction(title: "Sort by last time changed", style: .default, handler: { _ in
                self.change(sortType: .lastChanged)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = sortBarButton
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func cancelBarButtonPressed(_ sender: UIBarButtonItem) {
        dismiss()
    }
    
    private func dismiss() {
        searchController.dismiss(animated: false, completion: nil)
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playlist: playlist, rootView: nil)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { dismiss() }
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        guard let items = itemsToAdd else { return }
        playlist.append(playables: items)
        guard appDelegate.storage.settings.isOnlineMode else { return }
        let songsToAdd = items.compactMap{ $0.asSong }
        firstly {
            self.appDelegate.librarySyncer.syncUpload(playlistToAddSongs: playlist, songs: songsToAdd)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Playlist Add Songs", error: error)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPlaylistDetail.rawValue {
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        }
    }

    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        fetchedResultsController.search(searchText: searchText)
        tableView.reloadData()
    }
    
}
