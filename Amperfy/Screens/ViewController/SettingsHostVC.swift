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
    
    lazy var settings: Settings = {
       return Settings()
    }()
    
    var changesAgent: [AnyCancellable] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        changesAgent = [AnyCancellable]()
        
        settings.isOfflineMode = self.appDelegate.storage.settings.isOfflineMode
        changesAgent.append(settings.$isOfflineMode.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isOfflineMode = newValue
            self.appDelegate.notificationHandler.post(name: .offlineModeChanged, object: nil, userInfo: nil)
        }))
        
        settings.isShowDetailedInfo = self.appDelegate.storage.settings.isShowDetailedInfo
        changesAgent.append(settings.$isShowDetailedInfo.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isShowDetailedInfo = newValue
        }))
        
        settings.isShowSongDuration = self.appDelegate.storage.settings.isShowSongDuration
        changesAgent.append(settings.$isShowSongDuration.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isShowSongDuration = newValue
        }))
        
        settings.isShowAlbumDuration = self.appDelegate.storage.settings.isShowAlbumDuration
        changesAgent.append(settings.$isShowAlbumDuration.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isShowAlbumDuration = newValue
        }))
        
        settings.isShowArtistDuration = self.appDelegate.storage.settings.isShowArtistDuration
        changesAgent.append(settings.$isShowArtistDuration.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isShowArtistDuration = newValue
        }))
        
        settings.isShowMusicPlayerSkipButtons = self.appDelegate.storage.settings.isShowMusicPlayerSkipButtons
        changesAgent.append(settings.$isShowMusicPlayerSkipButtons.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isShowMusicPlayerSkipButtons = newValue
        }))
        
        settings.screenLockPreventionPreference = self.appDelegate.storage.settings.screenLockPreventionPreference
        changesAgent.append(settings.$screenLockPreventionPreference.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.screenLockPreventionPreference = newValue
        }))
        
        settings.streamingMaxBitratePreference = self.appDelegate.storage.settings.streamingMaxBitratePreference
        changesAgent.append(settings.$streamingMaxBitratePreference.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.streamingMaxBitratePreference = newValue
        }))
         
        settings.streamingFormatPreference = self.appDelegate.storage.settings.streamingFormatPreference
        changesAgent.append(settings.$streamingFormatPreference.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.streamingFormatPreference = newValue
        }))       
        
        settings.cacheTranscodingFormatPreference = self.appDelegate.storage.settings.cacheTranscodingFormatPreference
        changesAgent.append(settings.$cacheTranscodingFormatPreference.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.cacheTranscodingFormatPreference = newValue
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
        
        settings.isScrobbleStreamedItems = self.appDelegate.storage.settings.isScrobbleStreamedItems
        changesAgent.append(settings.$isScrobbleStreamedItems.sink(receiveValue: { newValue in
            self.appDelegate.storage.settings.isScrobbleStreamedItems = newValue
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
