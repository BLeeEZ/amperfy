//
//  BackendAudioPlayer.swift
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
import AVFoundation
import UIKit
import os.log
import PromiseKit

protocol BackendAudioPlayerNotifiable {
    func didElapsedTimeChange()
    func stop()
    func playPrevious()
    func playNext()
    func didItemFinishedPlaying()
    func notifyItemPreparationFinished()
    func notifyErrorOccured(error: Error)
}

enum PlayType {
    case stream
    case cache
}

class BackendAudioPlayer {

    private let playableDownloader: DownloadManageable
    private let cacheProxy: PlayableFileCachable
    private let backendApi: BackendApi
    private let userStatistics: UserStatistics
    private let player: AVPlayer
    private let eventLogger: EventLogger
    private let updateElapsedTimeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    
    public var isOfflineMode: Bool = false
    public var isAutoCachePlayedItems: Bool = true
    public private(set) var isPlaying: Bool = false
    public private(set) var playType: PlayType?

    var responder: BackendAudioPlayerNotifiable?
    var isPlayableLoaded: Bool {
        return player.currentItem?.status == AVPlayerItem.Status.readyToPlay
    }
    var isStopped: Bool {
        return playType == nil
    }
    var elapsedTime: Double {
        guard isPlayableLoaded else { return 0.0 }
        let elapsedTimeInSeconds = player.currentTime().seconds
        guard elapsedTimeInSeconds.isFinite else { return 0.0 }
        return elapsedTimeInSeconds
    }
    var duration: Double {
        guard isPlayableLoaded,
              let duration = player.currentItem?.asset.duration.seconds,
              duration.isFinite else {
            return 0.0
        }
        return duration
    }
    var canBeContinued: Bool {
        return player.currentItem != nil
    }
    
    init(mediaPlayer: AVPlayer, eventLogger: EventLogger, backendApi: BackendApi, playableDownloader: DownloadManageable, cacheProxy: PlayableFileCachable, userStatistics: UserStatistics) {
        self.player = mediaPlayer
        self.backendApi = backendApi
        self.eventLogger = eventLogger
        self.playableDownloader = playableDownloader
        self.cacheProxy = cacheProxy
        self.userStatistics = userStatistics

        self.player.allowsExternalPlayback = false // Disable video transmission via AirPlay -> only audio
        player.addPeriodicTimeObserver(forInterval: updateElapsedTimeInterval, queue: DispatchQueue.main) { [weak self] time in
            if let self = self {
                self.responder?.didElapsedTimeChange()
            }
        }
    }
    
    @objc private func itemFinishedPlaying() {
        responder?.didItemFinishedPlaying()
    }
    
    func continuePlay() {
        isPlaying = true
        player.play()
    }
    
    func pause() {
        isPlaying = false
        player.pause()
    }
    
    func stop() {
        isPlaying = false
        clearPlayer()
    }
    
    func seek(toSecond: Double) {
        player.seek(to: CMTime(seconds: toSecond, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    func requestToPlay(playable: AbstractPlayable) {
        if !playable.isPlayableOniOS, let contentType = playable.contentType {
            clearPlayer()
            eventLogger.info(topic: "Player Info", statusCode: .playerError, message: "Content type \"\(contentType)\" of \"\(playable.displayString)\" is not playable via Amperfy.", displayPopup: true)
            self.responder?.notifyItemPreparationFinished()
        } else if playable.isCached {
            insertCachedPlayable(playable: playable)
            self.continuePlay()
            self.responder?.notifyItemPreparationFinished()
        } else if !isOfflineMode{
            firstly {
                insertStreamPlayable(playable: playable)
            }.done {
                if self.isAutoCachePlayedItems {
                    self.playableDownloader.download(object: playable)
                }
                self.continuePlay()
                self.responder?.notifyItemPreparationFinished()
            }.catch { error in
                self.stop()
                self.responder?.notifyErrorOccured(error: error)
                self.responder?.notifyItemPreparationFinished()
                self.eventLogger.report(topic: "Player", error: error)
            }
        } else {
            clearPlayer()
            self.responder?.notifyItemPreparationFinished()
        }
    }
    
    private func clearPlayer() {
        playType = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
    
    private func insertCachedPlayable(playable: AbstractPlayable) {
        guard let playableData = cacheProxy.getFile(forPlayable: playable)?.data else {
            return
        }
        os_log(.default, "Play item: %s", playable.displayString)
        playType = .cache
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
        let itemUrl = playableData.createLocalUrl(fileName: "curPlayItem.mp3")
        insert(playable: playable, withUrl: itemUrl)
    }
    
    private func insertStreamPlayable(playable: AbstractPlayable) -> Promise<Void> {
        return firstly {
            backendApi.generateUrl(forStreamingPlayable: playable)
        }.get { streamUrl in
            os_log(.default, "Stream item: %s", playable.displayString)
            self.playType = .stream
            if playable.isSong { self.userStatistics.playedSong(isPlayedFromCache: false) }
            self.insert(playable: playable, withUrl: streamUrl)
        }.asVoid()
    }

    private func insert(playable: AbstractPlayable, withUrl url: URL) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        var item: AVPlayerItem?
        if let mimeType = playable.iOsCompatibleContentType {
            let asset: AVURLAsset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey" : mimeType])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(itemFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

}
