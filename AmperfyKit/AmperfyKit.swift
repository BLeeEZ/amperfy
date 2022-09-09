//
//  AmperfyKit.swift
//  AmperfyKit
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
import MediaPlayer
import os.log

public class AmperKit {
    
    static let name = "Amperfy"
    static var version: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }
    static var buildNumber: String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
    }
    
    private static var inst: AmperKit?
    public static var shared: AmperKit {
        if inst == nil { inst = AmperKit() }
        return inst!
    }
    
    public lazy var log = {
        return OSLog(subsystem: "Amperfy", category: "AppDelegate")
    }()
    public lazy var persistentStorage = {
        return PersistentStorage()
    }()
    public lazy var library = {
        return LibraryStorage(context: persistentStorage.context)
    }()
    public lazy var duplicateEntitiesResolver = {
        return DuplicateEntitiesResolver(persistentStorage: persistentStorage)
    }()
    public lazy var eventLogger = {
        return EventLogger(persistentContainer: persistentStorage.persistentContainer)
    }()
    public lazy var backendApi: BackendProxy = {
        return BackendProxy(eventLogger: eventLogger)
    }()
    public lazy var notificationHandler: EventNotificationHandler = {
        return EventNotificationHandler()
    }()
    public lazy var player: PlayerFacade = {
        let backendAudioPlayer = BackendAudioPlayer(mediaPlayer: AVPlayer(), eventLogger: eventLogger, backendApi: backendApi, playableDownloader: playableDownloadManager, cacheProxy: library, userStatistics: userStatistics)
        let playerData = library.getPlayerData()
        let queueHandler = PlayQueueHandler(playerData: playerData)
        let curPlayer = AudioPlayer(coreData: playerData, queueHandler: queueHandler, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
        
        let playerDownloadPreparationHandler = PlayerDownloadPreparationHandler(playerStatus: playerData, queueHandler: queueHandler, playableDownloadManager: playableDownloadManager)
        curPlayer.addNotifier(notifier:  playerDownloadPreparationHandler)
        let songPlayedSyncer = SongPlayedSyncer(musicPlayer: curPlayer, backendAudioPlayer: backendAudioPlayer, scrobbleSyncer: scrobbleSyncer)
        curPlayer.addNotifier(notifier: songPlayedSyncer)

        let facadeImpl = PlayerFacadeImpl(playerStatus: playerData, queueHandler: queueHandler, musicPlayer: curPlayer, library: library, playableDownloadManager: playableDownloadManager, backendAudioPlayer: backendAudioPlayer, userStatistics: userStatistics)
        facadeImpl.isOfflineMode = persistentStorage.settings.isOfflineMode
        
        let audioSessionHandler = AudioSessionHandler(musicPlayer: curPlayer)
        audioSessionHandler.configureObserverForAudioSessionInterruption(audioSession: AVAudioSession.sharedInstance())
        audioSessionHandler.configureBackgroundPlayback(audioSession: AVAudioSession.sharedInstance())
        let nowPlayingInfoCenterHandler = NowPlayingInfoCenterHandler(musicPlayer: curPlayer, backendAudioPlayer: backendAudioPlayer, nowPlayingInfoCenter: MPNowPlayingInfoCenter.default(), persistentStorage: persistentStorage)
        curPlayer.addNotifier(notifier: nowPlayingInfoCenterHandler)
        let remoteCommandCenterHandler = RemoteCommandCenterHandler(musicPlayer: facadeImpl, backendAudioPlayer: backendAudioPlayer, remoteCommandCenter: MPRemoteCommandCenter.shared())
        remoteCommandCenterHandler.configureRemoteCommands()
        curPlayer.addNotifier(notifier: remoteCommandCenterHandler)
        let notificationAdapter = PlayerNotificationAdapter(notificationHandler: notificationHandler)
        curPlayer.addNotifier(notifier: notificationAdapter)

        return facadeImpl
    }()
    public lazy var playableDownloadManager: DownloadManageable = {
        let artworkExtractor = EmbeddedArtworkExtractor()
        let dlDelegate = PlayableDownloadDelegate(backendApi: backendApi, artworkExtractor: artworkExtractor)
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        let dlManager = DownloadManager(name: "PlayableDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, notificationHandler: notificationHandler, eventLogger: eventLogger)
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).PlayableDownloader.background")
        var urlSession = URLSession(configuration: configuration, delegate: dlManager, delegateQueue: nil)
        dlManager.urlSession = urlSession
        
        return dlManager
    }()
    public lazy var artworkDownloadManager: DownloadManageable = {
        let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
        let requestManager = DownloadRequestManager(persistentStorage: persistentStorage, downloadDelegate: dlDelegate)
        requestManager.clearAllDownloadsIfAllHaveFinished()
        let dlManager = DownloadManager(name: "ArtworkDownloader", persistentStorage: persistentStorage, requestManager: requestManager, downloadDelegate: dlDelegate, notificationHandler: notificationHandler, eventLogger: eventLogger)
        dlManager.isFailWithPopupError = false
        
        dlManager.preDownloadIsValidCheck = { (object: Downloadable) -> Bool in
            guard let artwork = object as? Artwork else { return false }
            switch self.persistentStorage.settings.artworkDownloadSetting {
            case .updateOncePerSession:
                return true
            case .onlyOnce:
                switch artwork.status {
                case .NotChecked, .FetchError:
                    return true
                case .IsDefaultImage, .CustomImage:
                    return false
                }
            case .never:
                return false
            }
        }
        
        let configuration = URLSessionConfiguration.default
        var urlSession = URLSession(configuration: configuration, delegate: dlManager, delegateQueue: nil)
        dlManager.urlSession = urlSession
        
        return dlManager
    }()
    public lazy var backgroundLibrarySyncer = {
        return BackgroundLibrarySyncer(persistentStorage: persistentStorage, backendApi: backendApi, playableDownloadManager: playableDownloadManager, eventLogger: eventLogger)
    }()
    public lazy var scrobbleSyncer = {
        return ScrobbleSyncer(persistentStorage: persistentStorage, backendApi: backendApi, eventLogger: eventLogger)
    }()
    public lazy var libraryUpdater = {
        return LibraryUpdater(persistentStorage: persistentStorage, backendApi: backendApi)
    }()
    public lazy var userStatistics = {
        return library.getUserStatistics(appVersion: Self.version)
    }()
    public lazy var localNotificationManager = {
        return LocalNotificationManager(userStatistics: userStatistics, persistentStorage: persistentStorage)
    }()
    public lazy var backgroundFetchTriggeredSyncer = {
        return BackgroundFetchTriggeredSyncer(persistentStorage: persistentStorage, backendApi: backendApi, notificationManager: localNotificationManager, playableDownloadManager: playableDownloadManager)
    }()
    public lazy var popupDisplaySemaphore = {
        return DispatchSemaphore(value: 1)
    }()
    public lazy var intentManager = {
        return IntentManager(persistentStorage: self.persistentStorage, library: self.library, player: self.player)
    }()

    public func reinit() {
        let playerData = library.getPlayerData()
        let queueHandler = PlayQueueHandler(playerData: playerData)
        player.reinit(playerStatus: playerData, queueHandler: queueHandler)
    }
    
}
