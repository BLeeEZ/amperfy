//
//  LibraryVC.swift
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

import Foundation
import UIKit
import AmperfyKit

class LibraryVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    private var librarySettings = LibraryDisplaySettings.defaultSettings
    private var editButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        tableView.register(nibName: IconLabelTableCell.typeName)
        tableView.rowHeight = IconLabelTableCell.rowHeight
        
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editingPressed))
        navigationItem.rightBarButtonItems = [editButton]
        librarySettings = appDelegate.storage.settings.libraryDisplaySettings
    }
    
    @objc private func editingPressed() {
        tableView.isEditing.toggle()
        editButton.title = tableView.isEditing ? "Done" : "Edit"
        editButton.style = tableView.isEditing ? .done : .plain
        if tableView.isEditing {
            tableView.insertSections(IndexSet(integer: 1), with: .bottom)
        } else {
            tableView.deleteSections(IndexSet(integer: 1), with: .fade)
        }
        tableView.visibleCells
            .compactMap { $0 as? IconLabelTableCell }
            .forEach{ $0.accessoryType = tableView.isEditing ? .none : .disclosureIndicator }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.library)
        tableView.reloadData()
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        for visibleCell in tableView.visibleCells {
            let cell = visibleCell as! IconLabelTableCell
            cell.refreshStyle()
            cell.accessoryType = tableView.isEditing ? .none : .disclosureIndicator
        }
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if tableView.isEditing {
            return 2
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return nil
        case 1: return "Hidden"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return librarySettings.combined[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: IconLabelTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        cell.display(libraryDisplayType: librarySettings.combined[indexPath.section][indexPath.row])
        cell.accessoryType = tableView.isEditing ? .none : .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else { return }
        switch librarySettings.combined[indexPath.section][indexPath.row] {
        case .favoriteArtists:
            performSegue(withIdentifier: LibraryDisplayType.artists.segueName, sender: LibraryDisplayType.favoriteArtists)
        case .favoriteAlbums:
            performSegue(withIdentifier: LibraryDisplayType.albums.segueName, sender: LibraryDisplayType.favoriteAlbums)
        case .newestAlbums:
            performSegue(withIdentifier: LibraryDisplayType.albums.segueName, sender: LibraryDisplayType.newestAlbums)
        case .recentAlbums:
            performSegue(withIdentifier: LibraryDisplayType.albums.segueName, sender: LibraryDisplayType.recentAlbums)
        case .favoriteSongs:
            performSegue(withIdentifier: LibraryDisplayType.songs.segueName, sender: LibraryDisplayType.favoriteSongs)
        default:
            performSegue(withIdentifier: librarySettings.combined[indexPath.section][indexPath.row].segueName, sender: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == LibraryDisplayType.artists.segueName, let type = sender as? LibraryDisplayType, type == .favoriteArtists {
            let vc = segue.destination as! ArtistsVC
            vc.displayFilter = .favorites
        }
        
        if segue.identifier == LibraryDisplayType.albums.segueName, let type = sender as? LibraryDisplayType, type == .favoriteAlbums {
            let vc = segue.destination as! AlbumsVC
            vc.displayFilter = .favorites
        }
        if segue.identifier == LibraryDisplayType.albums.segueName, let type = sender as? LibraryDisplayType, type == .newestAlbums {
            let vc = segue.destination as! AlbumsVC
            vc.displayFilter = .newest
        }
        if segue.identifier == LibraryDisplayType.albums.segueName, let type = sender as? LibraryDisplayType, type == .recentAlbums {
            let vc = segue.destination as! AlbumsVC
            vc.displayFilter = .recent
        }
        
        if segue.identifier == LibraryDisplayType.songs.segueName, let type = sender as? LibraryDisplayType, type == .favoriteSongs {
            let vc = segue.destination as! SongsVC
            vc.displayFilter = .favorites
        }
    }
    
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let fromAction = librarySettings.combined[fromIndexPath.section][fromIndexPath.row]
        librarySettings.combined[fromIndexPath.section].remove(at: fromIndexPath.row)
        librarySettings.combined[to.section].insert(fromAction, at: to.row)
        appDelegate.storage.settings.libraryDisplaySettings = librarySettings
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0: return 0.0
        case 1: return CommonScreenOperations.tableSectionHeightLarge
        default: return 0.0
        }
    }
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return tableView.isEditing
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
}
