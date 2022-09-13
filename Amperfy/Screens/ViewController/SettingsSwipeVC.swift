//
//  SettingsSwipeVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.02.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class SettingsSwipeVC: UITableViewController {

    var appDelegate: AppDelegate!
    
    private var actionSettings = SwipeActionSettings.defaultSettings

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: IconLabelTableCell.typeName)
        tableView.rowHeight = IconLabelTableCell.rowHeight
        
        actionSettings = appDelegate.storage.settings.swipeActionSettings
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.isEditing = true
        tableView.reloadData()
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        for visibleCell in tableView.visibleCells {
            let cell = visibleCell as! IconLabelTableCell
            cell.refreshStyle()
        }
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Leading swipe"
        case 1: return "Trailing swipe"
        case 2: return "Not used"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actionSettings.combined[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: IconLabelTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        cell.display(action: actionSettings.combined[indexPath.section][indexPath.row])
        return cell
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let fromAction = actionSettings.combined[fromIndexPath.section][fromIndexPath.row]
        actionSettings.combined[fromIndexPath.section].remove(at: fromIndexPath.row)
        actionSettings.combined[to.section].insert(fromAction, at: to.row)
        appDelegate.storage.settings.swipeActionSettings = actionSettings
    }
    

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

}
