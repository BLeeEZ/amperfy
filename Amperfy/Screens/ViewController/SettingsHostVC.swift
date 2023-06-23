//
//  SettingsHostVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.09.22.
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
import AmperfyKit
import UIKit
import SwiftUI
import Combine

class SettingsHostVC: UIViewController {
    
    lazy var appDelegate: AppDelegate = {
        return (UIApplication.shared.delegate as! AppDelegate)
    }()
    
    lazy var settings: Settings = {
       return Settings()
    }()
    
    var changesAgent: [AnyCancellable] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        settings.isOfflineMode = self.appDelegate.storage.settings.isOfflineMode
        changesAgent.append(settings.$isOfflineMode.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isOfflineMode = newValue
        }))
        
        settings.sleepTimerInterval = self.appDelegate.storage.settings.sleepTimerInterval
        changesAgent.append(settings.$sleepTimerInterval.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.sleepTimerInterval = newValue
        }))
        
        settings.sleepTimer = self.appDelegate.sleepTimer
        changesAgent.append(settings.$sleepTimer.sink(receiveValue: { newValue in
            self.appDelegate.sleepTimer = newValue
        }))
        
        settings.isAutoCacheLatestSongs = self.appDelegate.storage.settings.isAutoDownloadLatestSongsActive
        changesAgent.append(settings.$isAutoCacheLatestSongs.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isAutoDownloadLatestSongsActive = newValue
        }))
        
        settings.isAutoCacheLatestPodcastEpisodes = self.appDelegate.storage.settings.isAutoDownloadLatestPodcastEpisodesActive
        changesAgent.append(settings.$isAutoCacheLatestPodcastEpisodes.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isAutoDownloadLatestPodcastEpisodesActive = newValue
        }))
        
        settings.isPlayerAutoCachePlayedItems = self.appDelegate.player.isAutoCachePlayedItems
        changesAgent.append(settings.$isPlayerAutoCachePlayedItems.sink(receiveValue: { newValue in
            self.appDelegate.player.isAutoCachePlayedItems = newValue
        }))
        
        settings.swipeActionSettings = self.appDelegate.storage.settings.swipeActionSettings
        changesAgent.append(settings.$swipeActionSettings.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.swipeActionSettings = newValue
        }))
        
        settings.cacheSizeLimit = self.appDelegate.storage.settings.cacheLimit
        changesAgent.append(settings.$cacheSizeLimit.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.cacheLimit = newValue
        }))
    }
    
    @IBSegueAction func segueToSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView:
            SettingsView()
                .environmentObject(settings)
                .environment(\.managedObjectContext, appDelegate.storage.main.context)
        )
    }
    
}
