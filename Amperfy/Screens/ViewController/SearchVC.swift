//
//  SearchVC.swift
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

class SearchVC: BasicTableViewController {

    private var playlistFetchedResultsController: PlaylistFetchedResultsController!
    private var artistFetchedResultsController: ArtistFetchedResultsController!
    private var albumFetchedResultsController: AlbumFetchedResultsController!
    private var songFetchedResultsController: SongsFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playlistFetchedResultsController = PlaylistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: .name, isGroupedInAlphabeticSections: false)
        playlistFetchedResultsController.delegate = self
        artistFetchedResultsController = ArtistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: .name, isGroupedInAlphabeticSections: false)
        artistFetchedResultsController.delegate = self
        albumFetchedResultsController = AlbumFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: .name, isGroupedInAlphabeticSections: false)
        albumFetchedResultsController.delegate = self
        songFetchedResultsController = SongsFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: .name, isGroupedInAlphabeticSections: false)
        songFetchedResultsController.delegate = self
        
        configureSearchController(placeholder: "Playlists, Songs and more", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.separatorStyle = .none
        
        containableAtIndexPathCallback = { (indexPath) in
            switch indexPath.section {
            case LibraryElement.Playlist.rawValue:
                return self.playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Artist.rawValue:
                return self.artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Album.rawValue:
                return self.albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Song.rawValue:
                return self.songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            default:
                return nil
            }
        }
        swipeCallback = { (indexPath, completionHandler) in
            self.determSwipeActionContext(at: indexPath) { actionContext in
                completionHandler(actionContext)
            }
        }
    }
    
    func determSwipeActionContext(at indexPath: IndexPath, completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> Void) {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                playlist.fetch(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: playlist))
            }
        case LibraryElement.Artist.rawValue:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                artist.fetch(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: artist))
            }
        case LibraryElement.Album.rawValue:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                album.fetch(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: album))
            }
        case LibraryElement.Song.rawValue:
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            completionHandler(SwipeActionContext(containable: song))
        default:
            completionHandler(nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.search)
    }

    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell), indexPath.section == LibraryElement.Song.rawValue else { return nil }
        let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
        return PlayContext(containable: song)
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return LibraryElement.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return "Playlists"
        case LibraryElement.Artist.rawValue:
            return "Artists"
        case LibraryElement.Album.rawValue:
            return "Albums"
        case LibraryElement.Song.rawValue:
            return "Songs"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Artist.rawValue:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Album.rawValue:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Song.rawValue:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(playlist: playlist, rootView: self)
            return cell
        case LibraryElement.Artist.rawValue:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: artist, rootView: self)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: album, rootView: self)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Artist.rawValue:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            return PlaylistTableCell.rowHeight
        case LibraryElement.Artist.rawValue:
            return GenericTableCell.rowHeight
        case LibraryElement.Album.rawValue:
            return GenericTableCell.rowHeight
        case LibraryElement.Song.rawValue:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
        case LibraryElement.Artist.rawValue:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case LibraryElement.Album.rawValue:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.toPlaylistDetail.rawValue:
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        case Segues.toArtistDetail.rawValue:
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        case Segues.toAlbumDetail.rawValue:
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        default: break
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            firstly {
                self.appDelegate.backendApi.createLibrarySyncer().searchArtists(searchText: searchText, persistentContainer: self.appDelegate.persistentStorage.persistentContainer)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
            }
            
            firstly {
                self.appDelegate.backendApi.createLibrarySyncer().searchAlbums(searchText: searchText, persistentContainer: self.appDelegate.persistentStorage.persistentContainer)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
            }
            
            firstly {
                self.appDelegate.backendApi.createLibrarySyncer().searchSongs(searchText: searchText, persistentContainer: self.appDelegate.persistentStorage.persistentContainer)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Songs Search", error: error)
            }

            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .all)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: false, displayFilter: .all)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: false, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .cached)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: true, displayFilter: .all)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: true, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else {
            playlistFetchedResultsController.clearResults()
            artistFetchedResultsController.hideResults()
            albumFetchedResultsController.hideResults()
            songFetchedResultsController.hideResults()
            tableView.separatorStyle = .none
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case playlistFetchedResultsController.fetchResultsController:
            section = LibraryElement.Playlist.rawValue
        case artistFetchedResultsController.fetchResultsController:
            section = LibraryElement.Artist.rawValue
        case albumFetchedResultsController.fetchResultsController:
            section = LibraryElement.Album.rawValue
        case songFetchedResultsController.fetchResultsController:
            section = LibraryElement.Song.rawValue
        default:
            return
        }
        
        super.applyChangesOfMultiRowType(controller, didChange: anObject, determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
