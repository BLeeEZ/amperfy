//
//  PlaylistAddLibraryVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.12.24.
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
import AmperfyKit
import PromiseKit
import CoreData

public protocol PlaylistVCAddable : UIViewController {
    var addToPlaylistManager: AddToPlaylistManager { get set }
}

extension LibraryDisplayType {
    public var vcForPlaylistAdd: PlaylistVCAddable? {
        switch self {
        case .genres:
            let vc = PlaylistAddGenresVC()
            return vc
        case .artists:
            let vc = PlaylistAddArtistsVC()
            vc.displayFilter = .all
            return vc
        case .favoriteArtists:
            let vc = PlaylistAddArtistsVC()
            vc.displayFilter = .favorites
            return vc
        case .newestAlbums:
            let vc = PlaylistAddAlbumsVC()
            vc.displayFilter = .newest
            return vc
        case .recentAlbums:
            let vc = PlaylistAddAlbumsVC()
            vc.displayFilter = .recent
            return vc
        case .favoriteAlbums:
            let vc = PlaylistAddAlbumsVC()
            vc.displayFilter = .favorites
            return vc
        case .albums:
            let vc = PlaylistAddAlbumsVC()
            vc.displayFilter = .all
            return vc
        case .songs:
            let vc = PlaylistAddSongsVC()
            vc.displayFilter = .all
            return vc
        case .favoriteSongs:
            let vc = PlaylistAddSongsVC()
            vc.displayFilter = .favorites
            return vc
        case .playlists:
            let vc = PlaylistAddPlaylistsVC()
            return vc
        case .directories:
            let vc = PlaylistAddMusicFoldersVC()
            return vc
        default:
            return nil
        }
    }
}

public class AddToPlaylistManager {
    public var playlist: Playlist!
    public var onDoneCB: VoidFunctionCallback?
    public var elementsToAdd = [AbstractPlayable]()
    public var rootView: UIViewController?
    
    private var appDelegate: AppDelegate
    
    init() {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
    }
    
    var title: String {
        let count = elementsToAdd.count
        if count != 0 {
            return "Add \(elementsToAdd.count) Songs to \"\(playlist.name)\""
        } else {
            return "Add Songs to \"\(playlist.name)\""
        }
    }
    
    func contains(playable: AbstractPlayable) -> Bool {
        return elementsToAdd.contains(where: {
            $0 == playable
        })
    }
    
    func toggleSelection(playable: AbstractPlayable) -> Bool {
        let markedIndex = elementsToAdd.firstIndex { $0 == playable }
        if let markedIndex = markedIndex {
            elementsToAdd.remove(at: markedIndex)
        } else {
            elementsToAdd.append(playable)
        }
        return markedIndex == nil
    }
    
    func append(playable: AbstractPlayable) {
        elementsToAdd.append(playable)
    }
    
    func remove(playable: AbstractPlayable) {
        elementsToAdd.removeAll(where: { $0 == playable})
    }
    
    func createDoneButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneBarButtonPressed))
    }
    
    @IBAction func doneBarButtonPressed(_ sender: UIBarButtonItem) {
        let songsToAdd = elementsToAdd.compactMap{ $0.asSong }

        if songsToAdd.count > 0 {
            firstly {
                self.appDelegate.librarySyncer.syncUpload(playlistToAddSongs: playlist, songs: songsToAdd)
            }.done {
                self.playlist.append(playables: songsToAdd)
                self.onDoneCB?()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Add Songs to Playlist", error: error)
            }.finally {
                self.rootView?.dismiss(animated: true, completion: nil)
            }
        } else {
            self.rootView?.dismiss(animated: true, completion: nil)
        }
    }
    
}

class PlaylistAddLibraryVC: KeyCommandTableViewController {

    override var sceneTitle: String? { addToPlaylistManager.playlist.name }
    
    private var doneButton: UIBarButtonItem!
    private var closeButton: UIBarButtonItem!
    private var libraryItems = [LibraryNavigatorItem]()
    
    public let addToPlaylistManager = AddToPlaylistManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.typeName)
        
        libraryItems = LibraryDisplaySettings.addToPlaylistSettings.inUse.map { LibraryNavigatorItem(title: $0.displayName, library: $0) }
        
        addToPlaylistManager.rootView = self
        doneButton = addToPlaylistManager.createDoneButton()
        closeButton = CloseBarButton(target: self, selector: #selector(cancelBarButtonPressed))
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = doneButton
    }
    
    func updateTitle() {
        setNavBarTitle(title: addToPlaylistManager.title)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateTitle()
    }
    
    @IBAction func cancelBarButtonPressed(_ sender: Any) {
        dismiss()
    }
    
    private func dismiss() {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UITableViewCell.typeName),
              let libraryItem = libraryItems[indexPath.row].library
        else { return UITableViewCell() }
        
        var content = cell.defaultContentConfiguration()
        LibraryNavigatorConfigurator.configureForLibrary(contentView: &content, libraryItem: libraryItem)

        cell.accessoryType = .disclosureIndicator
        cell.contentConfiguration = content
        
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return libraryItems.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let nextVC = libraryItems[indexPath.row].library?.vcForPlaylistAdd else { return }
        nextVC.addToPlaylistManager = addToPlaylistManager
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
}
