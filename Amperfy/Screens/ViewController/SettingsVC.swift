//
//  SettingsVC.swift
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

class SettingsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildNumberLabel: UILabel!
    @IBOutlet weak var offlineModeSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        versionLabel.text = AppDelegate.version
        buildNumberLabel.text = AppDelegate.buildNumber
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.settings)
        offlineModeSwitch.isOn = appDelegate.storage.settings.isOfflineMode
    }
    
    @IBAction func triggeredOfflineModeSwitch(_ sender: Any) {
        appDelegate.storage.settings.isOfflineMode = offlineModeSwitch.isOn
        appDelegate.player.isOfflineMode = offlineModeSwitch.isOn
        if !offlineModeSwitch.isOn {
            appDelegate.backgroundLibrarySyncer.start()
            appDelegate.scrobbleSyncer.start()
        } else {
            appDelegate.backgroundLibrarySyncer.stop()
        }
    }
    
    @IBAction func resetAppPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Reset app data", message: "Are you sure to reset app data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.scrobbleSyncer.stopAndWait()
            self.appDelegate.artworkDownloadManager.stopAndWait()
            self.appDelegate.playableDownloadManager.stopAndWait()
            self.appDelegate.storage.main.context.reset()
            self.appDelegate.storage.loginCredentials = nil
            self.appDelegate.storage.main.library.cleanStorage()
            self.appDelegate.storage.isLibrarySyncInfoReadByUser = false
            self.appDelegate.storage.isLibrarySynced = false
            self.deleteViewControllerCaches()
            self.appDelegate.reinit()
            self.performSegue(withIdentifier: Segues.toLogin.rawValue, sender: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
    private func deleteViewControllerCaches() {
        ArtistFetchedResultsController.deleteCache()
        AlbumFetchedResultsController.deleteCache()
        SongsFetchedResultsController.deleteCache()
        GenreFetchedResultsController.deleteCache()
        PlaylistSelectorFetchedResultsController.deleteCache()
        MusicFolderFetchedResultsController.deleteCache()
        PodcastFetchedResultsController.deleteCache()
    }
    
}
