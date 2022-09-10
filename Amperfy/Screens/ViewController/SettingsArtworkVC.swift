//
//  SettingsArtworkVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.04.22.
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

class SettingsArtworkVC: UITableViewController {
    
    static let artworkNotCheckedThreshold = 10
    
    var appDelegate: AppDelegate!
    var timer: Timer?
    
    @IBOutlet weak var artworkNotCheckedCountLabel: UILabel!
    @IBOutlet weak var cachedArtworksCountLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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
        appDelegate.storage.async.perform { asyncCompanion in
            let artworkNotCheckedCount = asyncCompanion.library.artworkNotCheckedCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let artworkNotCheckedDisplayCount = artworkNotCheckedCount > Self.artworkNotCheckedThreshold ? artworkNotCheckedCount : 0
                self.artworkNotCheckedCountLabel.text = String(artworkNotCheckedDisplayCount)
            }
            let cachedArtworkCount = asyncCompanion.library.cachedArtworkCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedArtworksCountLabel.text = String(cachedArtworkCount)
            }
        }.catch { error in }
    }
    
    @IBAction func downloadAllArtworksInLibraryPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Download all artworks in library", message: "This action will add all uncached artworks to the download queue. With this action a lot network traffic can be generated and device storage capacity will be taken. Continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default , handler: { _ in
            let allArtworksToDownload = self.appDelegate.storage.main.library.getArtworksForCompleteLibraryDownload()
            self.appDelegate.artworkDownloadManager.download(objects: allArtworksToDownload)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }

}
