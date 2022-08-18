//
//  SettingsLibraryVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 17.02.21.
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

import Foundation
import UIKit
import AmperfyKit

class SettingsLibraryVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var timer: Timer?
    
    @IBOutlet weak var artistsCountLabel: UILabel!
    @IBOutlet weak var albumsCountLabel: UILabel!
    @IBOutlet weak var songsCountLabel: UILabel!
    @IBOutlet weak var playlistsCountLabel: UILabel!
    @IBOutlet weak var podcastsCountLabel: UILabel!
    @IBOutlet weak var podcastEpisodesCountLabel: UILabel!
    
    @IBOutlet weak var autoSyncProgressLabel: UILabel!
    
    @IBOutlet weak var autoDownloadLastestSongsSwitch: UISwitch!
    @IBOutlet weak var autoDownloadLastestPodcastEpisodesSwitch: UISwitch!
    
    @IBOutlet weak var cachedSongsCountLabel: UILabel!
    @IBOutlet weak var cachedPodcastEpisodesCountLabel: UILabel!
    @IBOutlet weak var cachedCompleteSizeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsLibrary)
        
        autoDownloadLastestSongsSwitch.isOn = appDelegate.persistentStorage.settings.isAutoDownloadLatestSongsActive
        autoDownloadLastestPodcastEpisodesSwitch.isOn = appDelegate.persistentStorage.settings.isAutoDownloadLatestPodcastEpisodesActive
        updateValues()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateValues), userInfo: nil, repeats: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func updateValues() {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)

            let playlistCount = library.playlistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playlistsCountLabel.text = String(playlistCount)
            }

            let artistCount = library.artistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artistsCountLabel.text = String(artistCount)
            }
            
            let albumCount = library.albumCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.albumsCountLabel.text = String(albumCount)
            }
            
            let podcastCount = library.podcastCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.podcastsCountLabel.text = String(podcastCount)
            }
            
            let podcastEpisodeCount = library.podcastEpisodeCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.podcastEpisodesCountLabel.text = String(podcastEpisodeCount)
            }
            
            let songCount = library.songCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songsCountLabel.text = String(songCount)
            }
            
            let albumWithSyncedSongsCount = library.albumWithSyncedSongsCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if albumCount < 1 {
                    self.autoSyncProgressLabel.text = String(format: "%.1f", 0.0) + "%"
                } else {
                    let progress = Float(albumWithSyncedSongsCount) * 100.0 / Float(albumCount)
                    self.autoSyncProgressLabel.text = String(format: "%.1f", progress) + "%"
                }
            }
            
            let cachedSongCount = library.cachedSongCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedSongsCountLabel.text = String(cachedSongCount)
            }
            
            let cachedPodcastEpisodesCount = library.cachedPodcastEpisodeCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedPodcastEpisodesCountLabel.text = String(cachedPodcastEpisodesCount)
            }
            
            let completeCacheSize = library.cachedPlayableSizeInByte
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedCompleteSizeLabel.text = completeCacheSize.asByteString
            }
        }
    }
    
    @IBAction func downloadAllSongsInLibraryPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Download all songs in library", message: "This action will add all uncached songs in \"Library -> Songs\" to the download queue. With this action a lot network traffic can be generated and device storage capacity will be taken. Continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default , handler: { _ in
            let allSongsToDownload = self.appDelegate.library.getSongsForCompleteLibraryDownload()
            self.appDelegate.playableDownloadManager.download(objects: allSongsToDownload)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
    @IBAction func deleteSongCachePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete Cache", message: "Are you sure to delete all downloaded files from cache?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.playableDownloadManager.stopAndWait()
            self.appDelegate.library.deleteCompleteSongCache()
            self.appDelegate.library.saveContext()
            self.appDelegate.playableDownloadManager.start()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
    @IBAction func autoDownloadLastestSongsSwitchPressed(_ sender: Any) {
        appDelegate.persistentStorage.settings.isAutoDownloadLatestSongsActive = autoDownloadLastestSongsSwitch.isOn
    }
    
    @IBAction func autoDownloadLastestPodcastEpisodesSwitchPressed(_ sender: Any) {
        appDelegate.persistentStorage.settings.isAutoDownloadLatestPodcastEpisodesActive = autoDownloadLastestPodcastEpisodesSwitch.isOn
    }
    
}
