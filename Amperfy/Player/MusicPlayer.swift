import Foundation
import AVFoundation
import MediaPlayer
import os.log

class MusicPlayer: NSObject, BackendAudioPlayerNotifiable  {
    
    static let progressTimeStartThreshold: Double = 15.0
    static let progressTimeEndThreshold: Double = 15.0
    
    var currentlyPlaying: AbstractPlayable? {
        return queueHandler.currentlyPlaying
    }

    private var playerStatus: PlayerStatusPersistent
    private var queueHandler: PlayQueueHandler
    private let backendAudioPlayer: BackendAudioPlayer
    private let userStatistics: UserStatistics
    private var notifierList = [MusicPlayable]()
    private let replayInsteadPlayPreviousTimeInSec = 5.0

    init(coreData: PlayerStatusPersistent, queueHandler: PlayQueueHandler, backendAudioPlayer: BackendAudioPlayer, userStatistics: UserStatistics) {
        self.playerStatus = coreData
        self.queueHandler = queueHandler
        self.backendAudioPlayer = backendAudioPlayer
        self.backendAudioPlayer.isAutoCachePlayedItems = coreData.isAutoCachePlayedItems
        self.userStatistics = userStatistics
        super.init()
        self.backendAudioPlayer.responder = self
    }

    func reinit(playerStatus: PlayerData, queueHandler: PlayQueueHandler) {
        self.playerStatus = playerStatus
        self.queueHandler = queueHandler
    }
    
    private func shouldCurrentItemReplayedInsteadOfPrevious() -> Bool {
        if !backendAudioPlayer.canBeContinued {
            return false
        }
        return backendAudioPlayer.elapsedTime >= replayInsteadPlayPreviousTimeInSec
    }

    private func replayCurrentItem() {
        os_log(.debug, "Replay")
        backendAudioPlayer.seek(toSecond: 0)
        play()
    }

    private func insertIntoPlayer(playable: AbstractPlayable) {
        userStatistics.playedItem(repeatMode: playerStatus.repeatMode, isShuffle: playerStatus.isShuffle)
        backendAudioPlayer.requestToPlay(playable: playable)
    }
    
    //BackendAudioPlayerNotifiable
    func notifyItemPreparationFinished() {
        notifyItemStartedPlaying()
    }
    
    //BackendAudioPlayerNotifiable
    func didItemFinishedPlaying() {
        if playerStatus.repeatMode == .single {
            replayCurrentItem()
        } else {
            playNext()
        }
    }
    
    func play() {
        if !backendAudioPlayer.canBeContinued {
            if let currentPlayable = currentlyPlaying {
                insertIntoPlayer(playable: currentPlayable)
            }
        } else {
            backendAudioPlayer.continuePlay()
            notifyItemStartedPlaying()
        }
    }

    func play(playable: AbstractPlayable) {
        let topWaitingQueueItem = queueHandler.waitingQueue.first
        let wasWaitingQueuePlaying = queueHandler.isWaitingQueuePlaying
        queueHandler.clearPlaylistQueues()
        queueHandler.appendToNextInMainQueue(playables: [playable])
        if queueHandler.waitingQueue.isEmpty {
            if queueHandler.isWaitingQueuePlaying {
                playNext()
            } else {
                insertIntoPlayer(playable: playable)
            }
        } else {
            play(playerIndex: PlayerIndex(queueType: .next, index: 0))
        }
        if let topWaitingQueueItem = topWaitingQueueItem, !wasWaitingQueuePlaying {
            queueHandler.insertFirstToWaitingQueue(playables: [topWaitingQueueItem])
        }
    }
    
    func play(playables: [AbstractPlayable]) {
        guard let firstPlayable = playables.first else { return }
        let topWaitingQueueItem = queueHandler.waitingQueue.first
        let wasWaitingQueuePlaying = queueHandler.isWaitingQueuePlaying
        queueHandler.clearPlaylistQueues()
        queueHandler.appendToNextInMainQueue(playables: playables)
        if queueHandler.waitingQueue.isEmpty {
            if queueHandler.isWaitingQueuePlaying {
                playNext()
            } else {
                insertIntoPlayer(playable: firstPlayable)
            }
        } else {
            play(playerIndex: PlayerIndex(queueType: .next, index: 0))
        }
        if let topWaitingQueueItem = topWaitingQueueItem, !wasWaitingQueuePlaying {
            queueHandler.insertFirstToWaitingQueue(playables: [topWaitingQueueItem])
        }
    }
    
    func play(playerIndex: PlayerIndex) {
        guard let playable = queueHandler.markAndGetPlayableAsPlaying(at: playerIndex) else {
            stop()
            return
        }
        insertIntoPlayer(playable: playable)
    }
    
    func playPreviousOrReplay() {
        if shouldCurrentItemReplayedInsteadOfPrevious() {
            replayCurrentItem()
        } else {
            playPrevious()
        }
    }

    //BackendAudioPlayerNotifiable
    func playPrevious() {
        if !queueHandler.prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: queueHandler.prevQueue.count-1))
        } else if playerStatus.repeatMode == .all, !queueHandler.nextQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .next, index: queueHandler.nextQueue.count-1))
        } else {
            replayCurrentItem()
        }
    }

    //BackendAudioPlayerNotifiable
    func playNext() {
        if queueHandler.waitingQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .waitingQueue, index: 0))
        } else if queueHandler.nextQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .next, index: 0))
        } else if playerStatus.repeatMode == .all, !queueHandler.prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
        } else {
            stop()
        }
    }
    
    func pause() {
        backendAudioPlayer.pause()
        notifyItemPaused()
    }
    
    //BackendAudioPlayerNotifiable
    func stop() {
        backendAudioPlayer.stop()
        playerStatus.stop()
        notifyPlayerStopped()
    }
    
    func togglePlay() {
        if(backendAudioPlayer.isPlaying) {
            pause()
        } else {
            play()
        }
    }
    
    private func seekToLastStoppedPlayTime() {
        if let playable = currentlyPlaying, playable.isPodcastEpisode, playable.playProgress > 0 {
            backendAudioPlayer.seek(toSecond: Double(playable.playProgress))
        }
    }

    //BackendAudioPlayerNotifiable
    func didElapsedTimeChange() {
        notifyElapsedTimeChanged()
        if let currentItem = currentlyPlaying {
            savePlayInformation(of: currentItem)
        }
    }
    
    private func savePlayInformation(of playable: AbstractPlayable) {
        let playDuration = backendAudioPlayer.duration
        let playProgress = backendAudioPlayer.elapsedTime
        if playDuration != 0.0, playProgress != 0.0, playable == currentlyPlaying {
            playable.playDuration = Int(playDuration)
            if playProgress > Self.progressTimeStartThreshold, playProgress < (playDuration - Self.progressTimeEndThreshold) {
                playable.playProgress = Int(playProgress)
            } else {
                playable.playProgress = 0
            }
        }
    }
    
    func addNotifier(notifier: MusicPlayable) {
        notifierList.append(notifier)
    }
    
    func removeAllNotifier() {
        notifierList.removeAll()
    }

    func notifyItemStartedPlaying() {
        for notifier in notifierList {
            notifier.didStartPlaying()
        }
        seekToLastStoppedPlayTime()
    }
    
    func notifyItemPaused() {
        for notifier in notifierList {
            notifier.didPause()
        }
    }
    
    func notifyPlayerStopped() {
        for notifier in notifierList {
            notifier.didStopPlaying()
        }
    }
    
    func notifyArtworkChanged() {
        for notifier in notifierList {
            notifier.didArtworkChange()
        }
    }
    
    func notifyElapsedTimeChanged() {
        for notifier in notifierList {
            notifier.didElapsedTimeChange()
        }
    }
    
    func notifyPlaylistUpdated() {
        for notifier in notifierList {
            notifier.didPlaylistChange()
        }
    }

}
