//
//  PlaylistDetailVC.swift
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
import AmperfyKit
import PromiseKit
import CoreData

class PlaylistDetailDiffableDataSource: BasicUITableViewDiffableDataSource {
    
    var playlist: Playlist!
    var isEditing = false
    
    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return isEditing
    }
    #endif

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        exectueAfterAnimation {
            self.playlist?.movePlaylistItem(fromIndex: sourceIndexPath.row, to: destinationIndexPath.row)
            
            guard self.appDelegate.storage.settings.isOnlineMode else { return }
            firstly {
                self.appDelegate.librarySyncer.syncUpload(playlistToUpdateOrder: self.playlist)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Upload Order Update", error: error)
            }
        }
        super.tableView(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        exectueAfterAnimation {
            self.playlist?.remove(at: indexPath.row)
            guard self.appDelegate.storage.settings.isOnlineMode else { return }
            firstly {
                self.appDelegate.librarySyncer.syncUpload(playlistToDeleteSong: self.playlist, index: indexPath.row)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Upload Entry Remove", error: error)
            }
        }
        super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
    }
    
}

class PlaylistDetailVC: SingleSnapshotFetchedResultsTableViewController<PlaylistItemMO> {

    override var sceneTitle: String? { "Library" }

    private var fetchedResultsController: PlaylistItemsFetchedResultsController!
    var playlist: Playlist!
    
    private var editButton: UIBarButtonItem!
    private var optionsButton: UIBarButtonItem!
    var detailOperationsView: GenericDetailTableHeader?
    
    override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
        let source = PlaylistDetailDiffableDataSource(tableView: tableView) { (tableView, indexPath, objectID) -> UITableViewCell? in
            guard let object = try? self.appDelegate.storage.main.context.existingObject(with: objectID),
                  let playlistItemMO = object as? PlaylistItemMO
            else {
                return UITableViewCell()
            }
            let playlistItem = PlaylistItem(library: self.appDelegate.storage.main.library, managedObject: playlistItemMO)
            return self.createCell(tableView, forRowAt: indexPath, playlistItem: playlistItem)
        }
        source.playlist = playlist
        return source
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        #if !targetEnvironment(macCatalyst)
        self.refreshControl = UIRefreshControl()
        #endif

        appDelegate.userStatistics.visited(.playlistDetail)
        fetchedResultsController = PlaylistItemsFetchedResultsController(forPlaylist: playlist, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        singleFetchedResultsController?.delegate = self
        singleFetchedResultsController?.fetch()
        
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        tableView.estimatedRowHeight = PlayableTableCell.rowHeight

        // Use a single button, two buttons don't work on catalyst
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditing))
        optionsButton = OptionsBarButton()

        optionsButton.menu = UIMenu.lazyMenu {
            EntityPreviewActionBuilder(container: self.playlist, on: self).createMenu()
        }
        
        let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
            infoCB: { "\(self.playlist.songCount) Song\(self.playlist.songCount == 1 ? "" : "s")" },
            playContextCb: {() in PlayContext(containable: self.playlist, playables: self.fetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.isOfflineMode) ?? [])},
            player: appDelegate.player,
            isInfoAlwaysHidden: true)
        let detailHeaderConfig = DetailHeaderConfiguration(entityContainer: playlist, rootView: self, playShuffleInfoConfig: playShuffleInfoConfig)
        detailOperationsView = GenericDetailTableHeader.createTableHeader(configuration: detailHeaderConfig)
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        snapshotDidChange = self.detailOperationsView?.refresh
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath).playable
        }
        playContextAtIndexPathCallback = { (indexPath) in
            return self.convertIndexPathToPlayContext(songIndexPath: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let playlistItem = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            if let song = playlistItem.playable {
                let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
                completionHandler(SwipeActionContext(containable: song, playContext: playContext))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.storage.settings.isOfflineMode {
            tableView.isEditing = false
        }
        refreshBarButtons()
        firstly {
            playlist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
        }.finally {
            self.detailOperationsView?.refresh()
        }
    }
    
    func refreshBarButtons() {
        var edititingBarButton: UIBarButtonItem? = nil
        if !tableView.isEditing {
            if appDelegate.storage.settings.isOnlineMode {
                edititingBarButton = editButton
                edititingBarButton?.title = "Edit"
                edititingBarButton?.style = .plain
                if playlist?.isSmartPlaylist ?? false {
                    edititingBarButton?.isEnabled = false
                }
            }
        } else {
            edititingBarButton = editButton
            edititingBarButton?.title = "Done"
            edititingBarButton?.style = .done
        }

        navigationItem.rightBarButtonItems = [optionsButton, edititingBarButton].compactMap{$0}
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = fetchedResultsController.getContextSongs(onlyCachedSongs: appDelegate.storage.settings.isOfflineMode)
        else { return nil }
        return PlayContext(containable: playlist, index: songIndexPath.row, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell)
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
    }

    @objc private func toggleEditing(sender: UIBarButtonItem) {
        // Hack for catalyst, since isEnabled is ignored
        guard sender.isEnabled else { return }

        if tableView.isEditing {
            self.endEditing()
        } else {
            self.startEditing()
        }
    }

    private func startEditing() {
        tableView.isEditing = true
        (diffableDataSource as? PlaylistDetailDiffableDataSource)?.isEditing = true
        detailOperationsView?.startEditing()
        refreshBarButtons()
    }
    
    private func endEditing() {
        tableView.isEditing = false
        (diffableDataSource as? PlaylistDetailDiffableDataSource)?.isEditing = false
        detailOperationsView?.endEditing()
        refreshBarButtons()
    }
    
    func createCell(_ tableView: UITableView, forRowAt indexPath: IndexPath, playlistItem: PlaylistItem) -> UITableViewCell {
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        if let playable = playlistItem.playable, let song = playable.asSong {
            cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(onlyCachedSongs: appDelegate.storage.settings.isOfflineMode)
        tableView.reloadData()
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        firstly {
            self.appDelegate.librarySyncer.syncDown(playlist: playlist)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
        }.finally {
            self.detailOperationsView?.refresh()
            self.refreshControl?.endRefreshing()
        }
    }

}
