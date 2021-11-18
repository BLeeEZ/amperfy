import Foundation
import AVFoundation
import MediaPlayer
import os.log

class MusicPlayer: NSObject, BackendAudioPlayerNotifiable {
    
    static let preDownloadCount = 3
    static let progressTimeStartThreshold: Double = 15.0
    static let progressTimeEndThreshold: Double = 15.0
    
    var prevQueue: [AbstractPlayable] {
        return queueHandler.prevQueue
    }
    var waitingQueue: [AbstractPlayable] {
        return queueHandler.waitingQueue
    }
    var nextQueue: [AbstractPlayable] {
        return queueHandler.nextQueue
    }

    var isPlaying: Bool {
        return backendAudioPlayer.isPlaying
    }
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable {
        return queueHandler.getPlayable(at: playerIndex)
    }
    var currentlyPlaying: AbstractPlayable? {
        if let playingItem = backendAudioPlayer.currentlyPlaying {
            return playingItem
        }
        return queueHandler.currentlyPlaying
    }
    var elapsedTime: Double {
        return backendAudioPlayer.elapsedTime
    }
    var duration: Double {
        return backendAudioPlayer.duration
    }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter?
    var isShuffle: Bool {
        get { return playerStatus.isShuffle }
        set {
            playerStatus.isShuffle = newValue
            notifyPlaylistUpdated()
        }
    }
    var repeatMode: RepeatMode {
        get { return playerStatus.repeatMode }
        set { playerStatus.repeatMode = newValue }
    }
    var isOfflineMode: Bool {
        get { return backendAudioPlayer.isOfflineMode }
        set { backendAudioPlayer.isOfflineMode = newValue }
    }
    var isAutoCachePlayedItems: Bool {
        get { return playerStatus.isAutoCachePlayedItems }
        set {
            playerStatus.isAutoCachePlayedItems = newValue
            backendAudioPlayer.isAutoCachePlayedItems = newValue
        }
    }

    private var playerStatus: PlayerStatusPersistent
    private var queueHandler: PlayQueueHandler
    private let library: LibraryStorage
    private var playableDownloadManager: DownloadManageable
    private let backendAudioPlayer: BackendAudioPlayer
    private let userStatistics: UserStatistics
    private var notifierList = [MusicPlayable]()
    private let replayInsteadPlayPreviousTimeInSec = 5.0
    private var remoteCommandCenter: MPRemoteCommandCenter?
    
    init(coreData: PlayerStatusPersistent, queueHandler: PlayQueueHandler, library: LibraryStorage, playableDownloadManager: DownloadManageable, backendAudioPlayer: BackendAudioPlayer, userStatistics: UserStatistics) {
        self.playerStatus = coreData
        self.queueHandler = queueHandler
        self.library = library
        self.playableDownloadManager = playableDownloadManager
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
        seek(toSecond: 0)
        play()
    }

    func seek(toSecond: Double) {
        userStatistics.usedAction(.playerSeek)
        backendAudioPlayer.seek(toSecond: toSecond)
    }
    
    func addToPlaylist(playable: AbstractPlayable) {
        queueHandler.addToPlaylist(playable: playable)
    }
    
    func addToPlaylist(playables: [AbstractPlayable]) {
        queueHandler.addToPlaylist(playables: playables)
    }
    
    func addToWaitingQueue(playable: AbstractPlayable) {
        queueHandler.addToWaitingQueue(playable: playable)
    }

    func removePlayable(at: PlayerIndex) {
        queueHandler.removePlayable(at: at)
    }
    
    func movePlayable(from: PlayerIndex, to: PlayerIndex) {
        queueHandler.movePlayable(from: from, to: to)
    }

    private func insertIntoPlayer(playable: AbstractPlayable) {
        userStatistics.playedItem(repeatMode: repeatMode, isShuffle: isShuffle)
        backendAudioPlayer.requestToPlay(playable: playable)
        extractEmbeddedArtwork(playable: playable)
        preDownloadNextItems()
    }
    
    private func extractEmbeddedArtwork(playable: AbstractPlayable) {
        if playable.isCached, playable.embeddedArtwork == nil, let embeddedImage = backendAudioPlayer.getEmbeddedArtworkFromID3Tag() {
            let embeddedArtwork = library.createEmbeddedArtwork()
            embeddedArtwork.setImage(fromData: embeddedImage.pngData())
            embeddedArtwork.owner = playable
            library.saveContext()
            notifyArtworkChanged()
        }
    }
    
    private func preDownloadNextItems() {
        guard playerStatus.isAutoCachePlayedItems else { return }
        let upcomingItemsCount = min(waitingQueue.count + nextQueue.count, Self.preDownloadCount)
        guard upcomingItemsCount > 0 else { return }
        
        let waitingQueueRangeEnd = min(waitingQueue.count, Self.preDownloadCount)
        if waitingQueueRangeEnd > 0 {
            for i in 0...waitingQueueRangeEnd-1 {
                let playable = waitingQueue[i]
                if !playable.isCached {
                    playableDownloadManager.download(object: playable)
                }
            }
        }
        let nextQueueRangeEnd = min(nextQueue.count, Self.preDownloadCount-waitingQueueRangeEnd)
        if nextQueueRangeEnd > 0 {
            for i in 0...nextQueueRangeEnd-1 {
                let playable = nextQueue[i]
                if !playable.isCached {
                    playableDownloadManager.download(object: playable)
                }
            }
        }
    }
    
    func notifyItemPreparationFinished() {
        if let curPlayable = backendAudioPlayer.currentlyPlaying {
            notifyItemStartedPlaying()
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didItemFinishedPlaying() {
        if repeatMode == .single {
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
        clearPlaylist()
        addToPlaylist(playable: playable)
        insertIntoPlayer(playable: playable)
    }
    
    func play(playerIndex: PlayerIndex) {
        guard let playable = queueHandler.markAndGetPlayableAsPlaying(at: playerIndex) else {
            stop()
            return
        }
        insertIntoPlayer(playable: playable)
    }
    
    func appendToNextQueueAndPlay(playable: AbstractPlayable) {
        addToPlaylist(playable: playable)
        play(playerIndex: PlayerIndex(queueType: .next, index: nextQueue.count-1))
    }
    
    func insertAsNextSongNoPlay(playable: AbstractPlayable) {
        addToPlaylist(playable: playable)
        queueHandler.movePlayable(
            from: PlayerIndex(queueType: .next, index: nextQueue.count-1),
            to: PlayerIndex(queueType: .next, index: 0)
        )
    }
    
    func playPreviousOrReplay() {
        if shouldCurrentItemReplayedInsteadOfPrevious() {
            replayCurrentItem()
        } else {
            playPrevious()
        }
    }

    func playPrevious() {
        if !prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: prevQueue.count-1))
        } else if repeatMode == .all, !nextQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .next, index: nextQueue.count-1))
        } else {
            replayCurrentItem()
        }
    }

    func playNext() {
        if waitingQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .waitingQueue, index: 0))
        } else if nextQueue.count > 0 {
            play(playerIndex: PlayerIndex(queueType: .next, index: 0))
        } else if repeatMode == .all, !prevQueue.isEmpty {
            play(playerIndex: PlayerIndex(queueType: .prev, index: 0))
        } else {
            stop()
        }
    }
    
    func pause() {
        backendAudioPlayer.pause()
        notifyItemPaused()
        if let playable = queueHandler.currentlyPlaying {
            updateNowPlayingInfo(playable: playable)
        }
    }
    
    func stop() {
        queueHandler.clearWaitingQueue()
        backendAudioPlayer.stop()
        playerStatus.stop()
        notifyPlayerStopped()
    }
    
    func togglePlay() {
        if(isPlaying) {
            pause()
        } else {
            play()
        }
    }
    
    func clearWaitingQueue() {
        queueHandler.clearWaitingQueue()
    }
    
    func clearPlaylist() {
        stop()
        queueHandler.removeAllItems()
    }
    
    func clearQueues() {
        stop()
        queueHandler.clearWaitingQueue()
        queueHandler.removeAllItems()
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
        changeRemoteCommandCenterControlsBasedOnCurrentPlayableType()
    }
    
    private func seekToLastStoppedPlayTime() {
        if let playable = currentlyPlaying, playable.isPodcastEpisode, playable.playProgress > 0 {
            seek(toSecond: Double(playable.playProgress))
        }
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
    
    func didElapsedTimeChange() {
        notifyElapsedTimeChanged()
        if let currentItem = currentlyPlaying {
            savePlayInformation(of: currentItem)
            updateNowPlayingInfo(playable: currentItem)
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

    func updateNowPlayingInfo(playable: AbstractPlayable) {
        let albumTitle = playable.asSong?.album?.name ?? ""
        nowPlayingInfoCenter?.nowPlayingInfo = [
            MPMediaItemPropertyTitle: playable.title,
            MPMediaItemPropertyAlbumTitle: albumTitle,
            MPMediaItemPropertyArtist: playable.creatorName,
            MPMediaItemPropertyPlaybackDuration: backendAudioPlayer.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: backendAudioPlayer.elapsedTime,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork.init(boundsSize: playable.image.size, requestHandler: { (size) -> UIImage in
                return playable.image
            })
        ]
    }
    
    func configureObserverForAudioSessionInterruption(audioSession: AVAudioSession) {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: audioSession)
    }
    
    @objc private func handleAudioSessionInterruption(notification: NSNotification) {
        guard let interruptionTypeRaw: NSNumber = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRaw.uintValue) else {
                os_log(.error, "Audio interruption type invalid")
                return
        }
        
        switch (interruptionType) {
        case AVAudioSession.InterruptionType.began:
            // Audio has stopped, already inactive
            // Change state of UI, etc., to reflect non-playing state
            os_log(.info, "Audio interruption began")
            pause()
        case AVAudioSession.InterruptionType.ended:
            // Make session active
            // Update user interface
            // AVAudioSessionInterruptionOptionShouldResume option
            os_log(.info, "Audio interruption ended")
            if let interruptionOptionRaw: NSNumber = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber {
                let interruptionOption = AVAudioSession.InterruptionOptions(rawValue: interruptionOptionRaw.uintValue)
                if interruptionOption == AVAudioSession.InterruptionOptions.shouldResume {
                    // Here you should continue playback
                    os_log(.info, "Audio interruption ended -> Resume playing")
                    play()
                }
            }
        default: break
        }
    }

    func configureBackgroundPlayback(audioSession: AVAudioSession) {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            try audioSession.setActive(true)
        } catch {
            os_log(.error, "Error Player: %s", error.localizedDescription)
        }
    }
    
    func configureRemoteCommands(remoteCommandCenter: MPRemoteCommandCenter) {
        self.remoteCommandCenter = remoteCommandCenter
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.playCommand.addTarget(handler: { (event) in
            self.play()
            return .success})
        
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.addTarget(handler: { (event) in
            self.pause()
            return .success})
        
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.addTarget(handler: { (event) in
            self.togglePlay()
            return .success})
        
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.addTarget(handler: { (event) in
            self.playPreviousOrReplay()
            return .success})

        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.addTarget(handler: { (event) in
            self.playNext()
            return .success})
        
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.addTarget(handler: { (event) in
            guard let command = event as? MPChangePlaybackPositionCommandEvent else { return .noSuchContent}
            self.seek(toSecond: command.positionTime)
            return .success})
        
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [15]
        remoteCommandCenter.skipBackwardCommand.addTarget(handler: { (event) in
            guard let command = event.command as? MPSkipIntervalCommand else { return .noSuchContent }
            let interval = Double(truncating: command.preferredIntervals[0])
            self.seek(toSecond: self.elapsedTime - interval)
            return .success})
        
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [30]
        remoteCommandCenter.skipForwardCommand.addTarget(handler: { (event) in
            guard let command = event.command as? MPSkipIntervalCommand else { return .noSuchContent }
            let interval = Double(truncating: command.preferredIntervals[0])
            self.seek(toSecond: self.elapsedTime + interval)
            return .success})
    }
    
    private func changeRemoteCommandCenterControlsBasedOnCurrentPlayableType() {
        guard let currentItem = currentlyPlaying, let remoteCommandCenter = remoteCommandCenter else { return }
        if currentItem.isSong {
            remoteCommandCenter.previousTrackCommand.isEnabled = true
            remoteCommandCenter.nextTrackCommand.isEnabled = true
            remoteCommandCenter.skipBackwardCommand.isEnabled = false
            remoteCommandCenter.skipForwardCommand.isEnabled = false
        } else if currentItem.isPodcastEpisode {
            remoteCommandCenter.previousTrackCommand.isEnabled = false
            remoteCommandCenter.nextTrackCommand.isEnabled = false
            remoteCommandCenter.skipBackwardCommand.isEnabled = true
            remoteCommandCenter.skipForwardCommand.isEnabled = true
        }
    }

}
