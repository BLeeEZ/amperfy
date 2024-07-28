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
    func didLyricsTimeChange(time: CMTime) // high refresh count
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
    private let networkMonitor: NetworkMonitorFacade
    private let updateElapsedTimeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    private let updateLyricsTimeInterval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    private let fileManager = CacheFileManager.shared
    private var audioSessionHandler: AudioSessionHandler

    private var userDefinedPlaybackRate: PlaybackRate = .one
    
    public var isOfflineMode: Bool = false
    public var isAutoCachePlayedItems: Bool = true
    public var streamingMaxBitrates: StreamingMaxBitrates = .init() {
        didSet {
            let streamingMaxBitrate = streamingMaxBitrates.getActive(networkMonitor: self.networkMonitor)
            os_log(.default, "Update Streaming Max Bitrate: %s %s", streamingMaxBitrate.description, (self.playType == .stream) ? "(active)" : "")
            if self.playType == .stream {
                player.currentItem?.preferredPeakBitRate = streamingMaxBitrate.asBitsPerSecondAV
            }
        }
    }
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
    var playbackRate: PlaybackRate {
        return userDefinedPlaybackRate
    }
    var canBeContinued: Bool {
        return player.currentItem != nil
    }
    
    init(mediaPlayer: AVPlayer, audioSessionHandler: AudioSessionHandler, eventLogger: EventLogger, backendApi: BackendApi, networkMonitor: NetworkMonitorFacade, playableDownloader: DownloadManageable, cacheProxy: PlayableFileCachable, userStatistics: UserStatistics) {
        self.player = mediaPlayer
        self.audioSessionHandler = audioSessionHandler
        self.backendApi = backendApi
        self.networkMonitor = networkMonitor
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
        player.addPeriodicTimeObserver(forInterval: updateLyricsTimeInterval, queue: DispatchQueue.main) { [weak self] time in
            if let self = self {
                self.responder?.didLyricsTimeChange(time: time)
            }
        }
    }
    
    @objc private func itemFinishedPlaying() {
        responder?.didItemFinishedPlaying()
    }
    
    func continuePlay() {
        isPlaying = true
        player.play()
        player.playImmediately(atRate: Float(userDefinedPlaybackRate.asDouble))
        WidgetUtils.setPlaybackStatus(isPlaying: isPlaying)
    }
    
    func pause() {
        isPlaying = false
        player.pause()
        WidgetUtils.setPlaybackStatus(isPlaying: isPlaying)
    }
    
    func stop() {
        isPlaying = false
        clearPlayer()
        WidgetUtils.setPlaybackStatus(isPlaying: isPlaying)
    }
    
    func setPlaybackRate(_ newValue: PlaybackRate) {
        userDefinedPlaybackRate = newValue
        player.playImmediately(atRate: Float(newValue.asDouble))
    }
    
    func seek(toSecond: Double) {
        player.seek(to: CMTime(seconds: toSecond, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    func requestToPlay(playable: AbstractPlayable, playbackRate: PlaybackRate, autoStartPlayback: Bool) {
        userDefinedPlaybackRate = playbackRate
        if let relFilePath = playable.relFilePath,
           fileManager.fileExits(relFilePath: relFilePath) {
            guard playable.isPlayableOniOS else {
                reactToIncompatibleContentType(contentType: playable.fileContentType ?? "", playableDisplayTitle: playable.displayString)
                return
            }
            insertCachedPlayable(playable: playable)
            if autoStartPlayback {
                self.continuePlay()
            } else {
                isPlaying = false
            }
            self.responder?.notifyItemPreparationFinished()
        } else if !isOfflineMode{
            guard playable.isPlayableOniOS || backendApi.isStreamingTranscodingActive else {
                reactToIncompatibleContentType(contentType: playable.fileContentType ?? "", playableDisplayTitle: playable.displayString)
                return
            }
            self.stop()
            firstly {
                insertStreamPlayable(playable: playable)
            }.done {
                if self.isAutoCachePlayedItems {
                    self.playableDownloader.download(object: playable)
                }
                if autoStartPlayback {
                    self.continuePlay()
                } else {
                    self.isPlaying = false
                }
                self.responder?.notifyItemPreparationFinished()
            }.catch { error in
                self.responder?.notifyErrorOccured(error: error)
                self.responder?.notifyItemPreparationFinished()
                self.eventLogger.report(topic: "Player", error: error)
            }
        } else {
            clearPlayer()
            self.responder?.notifyItemPreparationFinished()
        }
    }
    
    private func reactToIncompatibleContentType(contentType: String, playableDisplayTitle: String) {
        clearPlayer()
        eventLogger.info(topic: "Player Info", statusCode: .playerError, message: "Content type \"\(contentType)\" of \"\(playableDisplayTitle)\" is not playable via Amperfy. Activating transcoding in Settings could resolve this issue.", displayPopup: true)
        self.responder?.notifyItemPreparationFinished()
    }
    
    private func clearPlayer() {
        playType = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
    
    private func insertCachedPlayable(playable: AbstractPlayable) {
        guard let fileURL = cacheProxy.getFileURL(forPlayable: playable) else {
            return
        }
        os_log(.default, "Play item: %s", playable.displayString)
        playType = .cache
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
        insert(playable: playable, withUrl: fileURL)
    }
    
    private func insertStreamPlayable(playable: AbstractPlayable) -> Promise<Void> {
        let streamingMaxBitrate = streamingMaxBitrates.getActive(networkMonitor: self.networkMonitor)
        return firstly {
            return backendApi.generateUrl(forStreamingPlayable: playable, maxBitrate: streamingMaxBitrate)
        }.get { streamUrl in
            os_log(.default, "Stream item (%s): %s", streamingMaxBitrate.description, playable.displayString)
            self.playType = .stream
            if playable.isSong { self.userStatistics.playedSong(isPlayedFromCache: false) }
            self.insert(playable: playable, withUrl: streamUrl, streamingMaxBitrate: streamingMaxBitrate)
        }.asVoid()
    }

    private func insert(playable: AbstractPlayable, withUrl url: URL, streamingMaxBitrate: StreamingMaxBitratePreference = .noLimit) {
        player.pause()
        audioSessionHandler.configureBackgroundPlayback()
        player.replaceCurrentItem(with: nil)
        var item: AVPlayerItem?
        if let mimeType = playable.iOsCompatibleContentType {
            let asset: AVURLAsset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey" : mimeType])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        item?.preferredPeakBitRate = streamingMaxBitrate.asBitsPerSecondAV
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(itemFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

}
