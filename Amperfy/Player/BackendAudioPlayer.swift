import Foundation
import AVFoundation
import AudioStreaming
import UIKit
import os.log

protocol BackendAudioPlayerNotifiable {
    func didElapsedTimeChange()
    func stop()
    func playPrevious()
    func playNext()
    func didItemFinishedPlaying()
    func notifyItemPreparationFinished()
}

enum PlayType {
    case stream
    case cache
}

enum BackendAudioQueueType {
    case play
    case queue
}

typealias NextPlayablePreloadCallback = () -> AbstractPlayable?

class BackendAudioPlayer {

    private let playableDownloader: DownloadManageable
    private let cacheProxy: PlayableFileCachable
    private let backendApi: BackendApi
    private let userStatistics: UserStatistics
    private let player: AudioPlayer
    private let eventLogger: EventLogger
    private let updateElapsedTimeInterval = 0.5
    private var elapsedTimeTimer: Timer?
    private let semaphore = DispatchSemaphore(value: 1)
    private var nextPreloadedPlayable: AbstractPlayable?
    
    public var isOfflineMode: Bool = false
    public var isAutoCachePlayedItems: Bool = true
    public var nextPlayablePreloadCB: NextPlayablePreloadCallback?
    public private(set) var isPlaying: Bool = false
    public private(set) var playType: PlayType?

    var responder: BackendAudioPlayerNotifiable?
    var isStopped: Bool {
        return playType == nil
    }
    var elapsedTime: Double {
        return player.progress
    }
    var duration: Double {
        let duration = player.duration
        guard duration.isFinite else { return 0.0 }
        return duration
    }
    var canBeContinued: Bool {
        return player.state == .paused
    }
    
    init(mediaPlayer: AudioPlayer, eventLogger: EventLogger, backendApi: BackendApi, playableDownloader: DownloadManageable, cacheProxy: PlayableFileCachable, userStatistics: UserStatistics) {
        self.player = mediaPlayer
        self.backendApi = backendApi
        self.eventLogger = eventLogger
        self.playableDownloader = playableDownloader
        self.cacheProxy = cacheProxy
        self.userStatistics = userStatistics
        self.player.delegate = self
    }
    
    @objc private func itemFinishedPlaying() {
        responder?.didItemFinishedPlaying()
    }
    
    func continuePlay() {
        isPlaying = true
        startElapsedTimeTimer()
        player.resume()
    }
    
    func pause() {
        isPlaying = false
        stopElapsedTimeTimer()
        player.pause()
    }
    
    func stop() {
        isPlaying = false
        stopElapsedTimeTimer()
        clearPlayer()
    }
    
    func seek(toSecond: Double) {
        player.seek(to: toSecond)
    }
    
    func requestToPlay(playable: AbstractPlayable) {
        semaphore.wait()
        if let nextPreloadedPlayable = nextPreloadedPlayable, nextPreloadedPlayable == playable {
            // Do nothing next preloaded playable has already been queued to player
            os_log(.default, "Preloaded: %s", nextPreloadedPlayable.displayString)
            self.nextPreloadedPlayable = nil
        } else {
            if playable.isCached {
                insertCachedPlayable(playable: playable)
            } else if !isOfflineMode{
                insertStreamPlayable(playable: playable)
                if isAutoCachePlayedItems {
                    playableDownloader.download(object: playable)
                }
            } else {
                clearPlayer()
            }
            self.continuePlay()
        }
        self.responder?.notifyItemPreparationFinished()
        startElapsedTimeTimer()
        semaphore.signal()
    }
    
    private func clearPlayer() {
        playType = nil
        player.stop()
        stopElapsedTimeTimer()
    }
    
    private func insertCachedPlayable(playable: AbstractPlayable, queueType: BackendAudioQueueType = .play) {
        guard let playableData = cacheProxy.getFile(forPlayable: playable)?.data else { return }
        os_log(.default, "Play item: %s", playable.displayString)
        playType = .cache
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
        let itemUrl = playableData.createLocalUrl(fileName: UUID().uuidString + ".mp3")
        insert(playable: playable, withUrl: itemUrl, queueType: queueType)
    }
    
    private func insertStreamPlayable(playable: AbstractPlayable, queueType: BackendAudioQueueType = .play) {
        guard let streamUrl = backendApi.generateUrl(forStreamingPlayable: playable) else { return }
        os_log(.default, "Stream item: %s", playable.displayString)
        playType = .stream
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: false) }
        insert(playable: playable, withUrl: streamUrl, queueType: queueType)
    }

    private func insert(playable: AbstractPlayable, withUrl url: URL, queueType: BackendAudioQueueType) {
        switch queueType {
        case .play:
            player.play(url: url)
        case .queue:
            player.queue(url: url)
        }
    }
    
    private func startElapsedTimeTimer() {
        if elapsedTimeTimer == nil {
            os_log(.default, "Player elapsed time start")
            elapsedTimeTimer = Timer.scheduledTimer(timeInterval: updateElapsedTimeInterval, target: self, selector: #selector(elapsedTimeTimerTicked), userInfo: nil, repeats: true)
        }
    }
    
    private func stopElapsedTimeTimer() {
        if let timer = elapsedTimeTimer {
            os_log(.default, "Player elapsed time stop")
            timer.invalidate()
            elapsedTimeTimer = nil
        }
    }
    
    @objc func elapsedTimeTimerTicked() {
        self.responder?.didElapsedTimeChange()
        if nextPreloadedPlayable == nil, elapsedTime.isFinite, elapsedTime > 0, duration.isFinite, duration > 0 {
            let remainingTime = duration - elapsedTime
            if remainingTime > 0, remainingTime < 10 {
                semaphore.wait()
                defer { semaphore.signal() }
                nextPreloadedPlayable = nextPlayablePreloadCB?()
                guard let nextPreloadedPlayable = nextPreloadedPlayable else { return }
                print("Next preload song is: \(nextPreloadedPlayable.displayString)")
                if nextPreloadedPlayable.isCached {
                    insertCachedPlayable(playable: nextPreloadedPlayable, queueType: .queue)
                } else if !isOfflineMode{
                    insertStreamPlayable(playable: nextPreloadedPlayable, queueType: .queue)
                    if isAutoCachePlayedItems {
                        playableDownloader.download(object: nextPreloadedPlayable)
                    }
                }
            }
        }
    }

}

extension BackendAudioPlayer: AudioPlayerDelegate {
    func audioPlayerDidStartPlaying(player: AudioPlayer, with entryId: AudioEntryId) {
        print("audioPlayerDidStartPlaying")
    }
    
    func audioPlayerDidFinishBuffering(player: AudioPlayer, with entryId: AudioEntryId) {
        print("audioPlayerDidFinishBuffering")
    }
    
    func audioPlayerStateChanged(player: AudioPlayer, with newState: AudioPlayerState, previous: AudioPlayerState) {
        print("audioPlayerStateChanged \(previous) \(newState)")
        if newState == .stopped {
            itemFinishedPlaying()
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AudioPlayer, entryId: AudioEntryId, stopReason: AudioPlayerStopReason, progress: Double, duration: Double) {
        print("audioPlayerDidFinishPlaying")
        if nextPreloadedPlayable != nil {
            itemFinishedPlaying()
        }
    }
    
    func audioPlayerUnexpectedError(player: AudioPlayer, error: AudioPlayerError) {
        print("audioPlayerUnexpectedError")
    }
    
    func audioPlayerDidCancel(player: AudioPlayer, queuedItems: [AudioEntryId]) {
        print("audioPlayerDidCancel")
    }
    
    func audioPlayerDidReadMetadata(player: AudioPlayer, metadata: [String : String]) {
        print("audioPlayerDidReadMetadata")
    }
    
}
