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
        playable.countPlayed()
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

    func play(context: PlayContext) {
        guard let activePlayable = context.getActivePlayable() else { return }
        let topUserQueueItem = queueHandler.userQueue.first
        let wasUserQueuePlaying = queueHandler.isUserQueuePlaying
        queueHandler.clearActiveQueue()
        queueHandler.appendActiveQueue(playables: context.playables)
        queueHandler.contextName = context.name
        if !wasUserQueuePlaying {
            if context.index == 0 {
                insertIntoPlayer(playable: activePlayable)
            } else {
                play(playerIndex: PlayerIndex(queueType: .next, index: context.index-1))
            }
            if let topUserQueueItem = topUserQueueItem {
                queueHandler.insertUserQueue(playables: [topUserQueueItem])
                play(playerIndex: PlayerIndex(queueType: .user, index: 0))
            }
        } else if context.index > 0, let currentlyPlayingElement = currentlyPlaying {
            _ = queueHandler.markAndGetPlayableAsPlaying(at: PlayerIndex(queueType: .next, index: context.index-1))
            queueHandler.insertUserQueue(playables: [currentlyPlayingElement])
            _ = queueHandler.markAndGetPlayableAsPlaying(at: PlayerIndex(queueType: .user, index: 0))
        }
        play()
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
        if queueHandler.userQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .user, index: 0))
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
    
    func stopButRemainIndex() {
        backendAudioPlayer.stop()
        notifyPlayerStopped()
    }
    
    func togglePlayPause() {
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

    func notifyShuffleUpdated() {
        for notifier in notifierList {
            notifier.didShuffleChange()
        }
    }

    func notifyRepeatUpdated() {
        for notifier in notifierList {
            notifier.didRepeatChange()
        }
    }

}
