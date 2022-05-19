import Foundation
import AVFoundation
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

struct PlayerItem {
let playable: AbstractPlayable
let url: URL
}

class BackendAudioPlayer: NSObject {

    private let playableDownloader: DownloadManageable
    private let cacheProxy: PlayableFileCachable
    private let backendApi: BackendApi
    private let userStatistics: UserStatistics
    private let player: HysteriaPlayer
    private let eventLogger: EventLogger
    private let updateElapsedTimeInterval = 0.5
    private var elapsedTimeTimer: Timer?
    private let semaphore = DispatchSemaphore(value: 1)
    private var playables = [PlayerItem]()
    
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
        return Double(player.playingItemCurrentTime())
    }
    var duration: Double {
        return Double(player.playingItemDurationTime())
    }
    var canBeContinued: Bool {
        return !playables.isEmpty
    }
    
    init(eventLogger: EventLogger, backendApi: BackendApi, playableDownloader: DownloadManageable, cacheProxy: PlayableFileCachable, userStatistics: UserStatistics) {
        self.player = HysteriaPlayer.sharedInstance()
        self.player.skipEmptySoundPlaying = false
        self.backendApi = backendApi
        self.eventLogger = eventLogger
        self.playableDownloader = playableDownloader
        self.cacheProxy = cacheProxy
        self.userStatistics = userStatistics
        super.init()
        self.player.delegate = self
        self.player.datasource = self
        startElapsedTimeTimer()
    }
    
    deinit {
        stopElapsedTimeTimer()
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
        player.seek(toTime: toSecond)
    }
    
    func requestToPlay(playable: AbstractPlayable) {
        semaphore.wait()
        if playables.count > 1, let nextPreloadedPlayable = playables.last?.playable, nextPreloadedPlayable == playables[playables.count-2].playable {
            // Do nothing next preloaded playable has already been queued to player
            os_log(.default, "Play preloaded: %s", nextPreloadedPlayable.displayString)
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
            //self.continuePlay()
        }
        self.responder?.notifyItemPreparationFinished()
        semaphore.signal()
    }
    
    private func clearPlayer() {
        playType = nil
        player.pause()
        //player.removeAllItems()
        playables.removeAll()
    }
    
    private func insertCachedPlayable(playable: AbstractPlayable, queueType: BackendAudioQueueType = .play) {
        guard let playableData = cacheProxy.getFile(forPlayable: playable)?.data else { return }
        switch queueType {
        case .play:
            os_log(.default, "Play local: %s", playable.displayString)
        case .queue:
            os_log(.default, "Queue local: %s", playable.displayString)
        }
        playType = .cache
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
        let itemUrl = playableData.createLocalUrl(fileName: UUID().uuidString + ".mp3")
        insert(playable: playable, withUrl: itemUrl, queueType: queueType)
    }
    
    private func insertStreamPlayable(playable: AbstractPlayable, queueType: BackendAudioQueueType = .play) {
        guard let streamUrl = backendApi.generateUrl(forStreamingPlayable: playable) else { return }
        switch queueType {
        case .play:
            os_log(.default, "Play stream: %s", playable.displayString)
        case .queue:
            os_log(.default, "Queue stream: %s", playable.displayString)
        }
        playType = .stream
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: false) }
        insert(playable: playable, withUrl: streamUrl, queueType: queueType)
    }

    private func insert(playable: AbstractPlayable, withUrl url: URL, queueType: BackendAudioQueueType) {
        switch queueType {
        case .play:
            playables.removeAll()
            playables.append(PlayerItem(playable: playable, url: url))
            player.fetchAndPlayPlayerItem(0)
        case .queue:
            playables.append(PlayerItem(playable: playable, url: url))
        }
    }
    
    private func startElapsedTimeTimer() {
        guard elapsedTimeTimer == nil else { return }
        os_log(.default, "Player elapsed time start")
        elapsedTimeTimer = Timer.scheduledTimer(timeInterval: updateElapsedTimeInterval, target: self, selector: #selector(elapsedTimeTimerTicked), userInfo: nil, repeats: true)
    }
    
    private func stopElapsedTimeTimer() {
        guard let timer = elapsedTimeTimer else { return }
        os_log(.default, "Player elapsed time stop")
        timer.invalidate()
        elapsedTimeTimer = nil
    }
    
    @objc func elapsedTimeTimerTicked() {
        self.responder?.didElapsedTimeChange()
    }

}

extension BackendAudioPlayer: HysteriaPlayerDelegate {

    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didReadyToPlayWithIdentifier identifier: HysteriaPlayerReadyToPlay) {
        print("didReadyToPlayWithIdentifier")
        switch identifier {
        case .currentItem:
            hysteriaPlayer.play()
        default:
            break
        }
    }
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, willChangePlayerItemAt index: Int) {
        print("willChangePlayerItemAt")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didChangeCurrentItem item: AVPlayerItem) {
        print("didChangeCurrentItem")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didEvictCurrentItem item: AVPlayerItem) {
        print("didEvictCurrentItem")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, rateDidChange rate: Float) {
        print("rateDidChange")
    }
    
    func hysteriaPlayerDidReachEnd(_ hysteriaPlayer: HysteriaPlayer) {
        print("hysteriaPlayerDidReachEnd")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didPreloadCurrentItemWith time: CMTime) {
        print("didPreloadCurrentItemWith")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didFailWithIdentifier identifier: HysteriaPlayerFailed, error: Error) {
        print("didFailWithIdentifier")
    }
    

    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didFailedWith item: AVPlayerItem?, toPlayToEndTimeWithError error: Error) {
        print("didFailedWith")
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didStallWith item: AVPlayerItem?) {
        print("didStallWith")
    }
    

}

extension BackendAudioPlayer: HysteriaPlayerDataSource {
    func numberOfItems(in hysteriaPlayer: HysteriaPlayer) -> Int {
        print("numberOfItems")
        return playables.count
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, urlForItemAt index: Int, preBuffer: Bool) -> URL {
        print("urlForItemAt")
        return playables[index].url
    }
}
/*
extension BackendAudioPlayer: STKAudioPlayerDelegate {
    func audioPlayer(_ audioPlayer: STKAudioPlayer, didStartPlayingQueueItemId queueItemId: NSObject) {
        print("didStartPlayingQueueItemId")
    }
    
    func audioPlayer(_ audioPlayer: STKAudioPlayer, didFinishBufferingSourceWithQueueItemId queueItemId: NSObject) {
        guard nextPreloadedPlayable == nil else { return }
        semaphore.wait()
        defer { semaphore.signal() }
        nextPreloadedPlayable = nextPlayablePreloadCB?()
        guard let nextPreloadedPlayable = nextPreloadedPlayable else { return }
        if nextPreloadedPlayable.isCached {
            insertCachedPlayable(playable: nextPreloadedPlayable, queueType: .queue)
        } else if !isOfflineMode{
            insertStreamPlayable(playable: nextPreloadedPlayable, queueType: .queue)
            if isAutoCachePlayedItems {
                playableDownloader.download(object: nextPreloadedPlayable)
            }
        }
    }
    
    func audioPlayer(_ audioPlayer: STKAudioPlayer, stateChanged state: STKAudioPlayerState, previousState: STKAudioPlayerState) {
    }
    
    func audioPlayer(_ audioPlayer: STKAudioPlayer, didFinishPlayingQueueItemId queueItemId: NSObject, with stopReason: STKAudioPlayerStopReason, andProgress progress: Double, andDuration duration: Double) {
        print("didFinishPlayingQueueItemId    \(stopReason)")
        if let currentPlayable = currentPlayable, let objectID = queueItemId as? String, currentPlayable.uniqueID == objectID {
            itemFinishedPlaying()
            self.currentPlayable = nil
        }
    }
    
    func audioPlayer(_ audioPlayer: STKAudioPlayer, unexpectedError errorCode: STKAudioPlayerErrorCode) {
        itemFinishedPlaying()
    }
    
}
*/
