//
//  SettingsArtworkDownloadVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 04.03.22.
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

import Foundation
import UIKit
import AmperfyKit

class SettingsArtworkDownloadTableCell: UITableViewCell {
    
    var isActive: Bool = false
    
    @IBOutlet weak var settingLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    func setStatusLabel(isActive: Bool) {
        self.isActive = isActive
        self.statusLabel?.isHidden = !isActive
        self.statusLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
    }
    
}

class SettingsArtworkDownloadVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var settingOptions = [ArtworkDownloadSetting]()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        settingOptions = ArtworkDownloadSetting.allCases
    }
    
    override func viewWillAppear(_ animated: Bool) {
        reload()
    }
    
    func reload() {
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingOptions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingsArtworkDownloadTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.settingLabel.text = settingOptions[indexPath.row].description
        cell.setStatusLabel(isActive: settingOptions[indexPath.row] == appDelegate.storage.settings.artworkDownloadSetting)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        appDelegate.storage.settings.artworkDownloadSetting = settingOptions[indexPath.row]
        reload()
    }
    
}
