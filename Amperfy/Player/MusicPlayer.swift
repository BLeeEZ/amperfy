import Foundation
import AVFoundation
import MediaPlayer
import os.log

protocol MusicPlayable {
    func didStartPlaying(playlistItem: PlaylistItem)
    func didPause()
    func didStopPlaying(playlistItem: PlaylistItem?)
    func didElapsedTimeChange()
    func didPlaylistChange()
}

enum RepeatMode: Int16 {
    case off
    case all
    case single

    mutating func switchToNextMode() {
        switch self {
        case .off:
            self = .all
        case .all:
            self = .single
        case .single:
            self = .off
        }
    }
    
    var description : String {
        switch self {
        case .off: return "Off"
        case .all: return "All"
        case .single: return "Single"
        }
    }
}

class MusicPlayer: NSObject, BackendAudioPlayerNotifiable {
    
    static let preDownloadCount = 3
    static let progressTimeStartThreshold: Double = 15.0
    static let progressTimeEndThreshold: Double = 15.0
    
    var playlist: Playlist { 
        return coreData.playlist
    }
    var isPlaying: Bool {
        return backendAudioPlayer.isPlaying
    }
    var currentlyPlaying: PlaylistItem? {
        if let playingItem = backendAudioPlayer.currentlyPlaying {
            return playingItem
        }
        return coreData.currentPlaylistItem
    }
    var elapsedTime: Double {
        return backendAudioPlayer.elapsedTime
    }
    var duration: Double {
        return backendAudioPlayer.duration
    }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter?
    var isShuffle: Bool {
        get { return coreData.isShuffle }
        set {
            coreData.isShuffle = newValue
            if let curPlaylistItem = coreData.currentPlaylistItem {
                backendAudioPlayer.updateCurrentlyPlayingReference(playlistItem: curPlaylistItem)
            }
            notifyPlaylistUpdated()
        }
    }
    var repeatMode: RepeatMode {
        get { return coreData.repeatMode }
        set { coreData.repeatMode = newValue }
    }
    var isAutoCachePlayedItems: Bool {
        get { return coreData.isAutoCachePlayedItems }
        set {
            coreData.isAutoCachePlayedItems = newValue
            backendAudioPlayer.isAutoCachePlayedItems = newValue
        }
    }

    private var coreData: PlayerData
    private var playableDownloadManager: DownloadManageable
    private let backendAudioPlayer: BackendAudioPlayer
    private let userStatistics: UserStatistics
    private var notifierList = [MusicPlayable]()
    private let replayInsteadPlayPreviousTimeInSec = 5.0
    private var remoteCommandCenter: MPRemoteCommandCenter?
    
    init(coreData: PlayerData, playableDownloadManager: DownloadManageable, backendAudioPlayer: BackendAudioPlayer, userStatistics: UserStatistics) {
        self.coreData = coreData
        self.playableDownloadManager = playableDownloadManager
        self.backendAudioPlayer = backendAudioPlayer
        self.backendAudioPlayer.isAutoCachePlayedItems = coreData.isAutoCachePlayedItems
        self.userStatistics = userStatistics
        super.init()
        self.backendAudioPlayer.responder = self
    }

    func reinit(coreData: PlayerData) {
        self.coreData = coreData
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
        coreData.addToPlaylist(playable: playable)
    }
    
    func addToPlaylist(playables: [AbstractPlayable]) {
        coreData.addToPlaylist(playables: playables)
    }
    
    func movePlaylistItem(fromIndex: Int, to: Int) {
        coreData.movePlaylistItem(fromIndex: fromIndex, to: to)
    }
    
    func removeFromPlaylist(at index: Int) {
        guard index < playlist.playables.count else { return }
        if playlist.playables.count <= 1 {
            stop()
        } else if index == coreData.currentIndex {
            playNext()
        }
        coreData.removeItemFromPlaylist(at: index)
    }
    
    private func prepareItemAndInsertIntoPlayer(playlistIndex: Int, reactionToError: FetchErrorReaction) {
        guard playlistIndex < playlist.playables.count else { return }
        let playlistItem = playlist.items[playlistIndex]
        userStatistics.playedItem(repeatMode: repeatMode, isShuffle: isShuffle)
        backendAudioPlayer.requestToPlay(playlistItem: playlistItem, reactionToError: reactionToError)
        coreData.currentIndex = playlistIndex
        preDownloadNextItems(playlistIndex: playlistIndex)
    }
    
    private func preDownloadNextItems(playlistIndex: Int) {
        guard coreData.isAutoCachePlayedItems else { return }
        var upcomingItemsCount = (playlist.playables.count-1) - playlistIndex
        if upcomingItemsCount > Self.preDownloadCount {
            upcomingItemsCount = Self.preDownloadCount
        }
        if upcomingItemsCount > 0 {
            for i in 1...upcomingItemsCount {
                let nextItemIndex = playlistIndex + i
                if let playable = playlist.items[nextItemIndex].playable, !playable.isCached {
                    playableDownloadManager.download(object: playable, notifier: nil, priority: .high)
                }
            }
        }
    }
    
    func notifyItemPreparationFinished() {
        if let curPlaylistItem = backendAudioPlayer.currentlyPlaying {
            notifyItemStartedPlaying(playlistItem: curPlaylistItem)
            if let playable = curPlaylistItem.playable {
                updateNowPlayingInfo(playable: playable)
            }
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
            play(elementInPlaylistAt: coreData.currentIndex)
        } else {
            backendAudioPlayer.continuePlay()
            if let curPlaylistItem = backendAudioPlayer.currentlyPlaying {
                notifyItemStartedPlaying(playlistItem: curPlaylistItem)
            }
        }
    }
    
    func play(playable: AbstractPlayable) {
        cleanPlaylist()
        addToPlaylist(playable: playable)
        play(elementInPlaylistAt: coreData.currentIndex)
    }
    
    func play(elementInPlaylistAt: Int, reactionToError: FetchErrorReaction = .playNext) {
        if elementInPlaylistAt >= 0, elementInPlaylistAt <= playlist.playables.count {
            prepareItemAndInsertIntoPlayer(playlistIndex: elementInPlaylistAt, reactionToError: reactionToError)
        } else {
            stop()
        }
    }
    
    func playPreviousOrReplay() {
        if shouldCurrentItemReplayedInsteadOfPrevious() {
            replayCurrentItem()
        } else {
            playPrevious()
        }
    }

    func playPrevious() {
        if let prevElementIndex = coreData.previousIndex {
            play(elementInPlaylistAt: prevElementIndex, reactionToError: .playPrevious)
        } else if repeatMode == .all, !playlist.playables.isEmpty {
            play(elementInPlaylistAt: playlist.lastPlayableIndex, reactionToError: .playPrevious)
        } else if !playlist.playables.isEmpty {
            play(elementInPlaylistAt: 0, reactionToError: .playPrevious)
        } else {
            stop()
        }
    }

    func playPreviousCached() {
        if let prevItemIndex = playlist.previousCachedItemIndex(downwardsFrom: coreData.currentIndex) {
            play(elementInPlaylistAt: prevItemIndex, reactionToError: .playPrevious)
        } else if repeatMode == .all, let prevItemIndex = playlist.previousCachedItemIndex(beginningAt: playlist.lastPlayableIndex) {
            play(elementInPlaylistAt: prevItemIndex, reactionToError: .playPrevious)
        } else {
            stop()
        }
    }
    
    func playNext() {
        if let nextItemIndex = coreData.nextIndex {
            play(elementInPlaylistAt: nextItemIndex)
        } else if repeatMode == .all, !playlist.playables.isEmpty {
            play(elementInPlaylistAt: 0)
        } else {
            stop()
        }
    }
    
    func playNextCached() {
        if let nextItemIndex = playlist.nextCachedItemIndex(upwardsFrom: coreData.currentIndex) {
            play(elementInPlaylistAt: nextItemIndex)
        } else if repeatMode == .all, let nextItemIndex = playlist.nextCachedItemIndex(beginningAt: 0) {
            play(elementInPlaylistAt: nextItemIndex)
        } else {
            stop()
        }
    }
    
    func pause() {
        backendAudioPlayer.pause()
        notifyItemPaused()
        if let playable = coreData.currentItem {
            updateNowPlayingInfo(playable: playable)
        }
    }
    
    func stop() {
        let stoppedPlaylistItem = currentlyPlaying
        backendAudioPlayer.stop()
        coreData.currentIndex = 0
        notifyPlayerStopped(playlistItem: stoppedPlaylistItem)
    }
    
    func togglePlay() {
        if(isPlaying) {
            pause()
        } else {
            play()
        }
    }
    
    func cleanPlaylist() {
        stop()
        coreData.removeAllItems()
    }
    
    func addNotifier(notifier: MusicPlayable) {
        notifierList.append(notifier)
    }
    
    func removeAllNotifier() {
        notifierList.removeAll()
    }
    
    func notifyItemStartedPlaying(playlistItem: PlaylistItem) {
        for notifier in notifierList {
            notifier.didStartPlaying(playlistItem: playlistItem)
        }
        seekToLastStoppedPlayTime(playlistItem: playlistItem)
        changeRemoteCommandCenterControlsBasedOnCurrentPlayableType()
    }
    
    private func seekToLastStoppedPlayTime(playlistItem: PlaylistItem) {
        if let playable = playlistItem.playable, playable.isPodcastEpisode, playable.playProgress > 0 {
            seek(toSecond: Double(playable.playProgress))
        }
    }
    
    func notifyItemPaused() {
        for notifier in notifierList {
            notifier.didPause()
        }
    }
    
    func notifyPlayerStopped(playlistItem: PlaylistItem?) {
        for notifier in notifierList {
            notifier.didStopPlaying(playlistItem: playlistItem)
        }
    }
    
    func didElapsedTimeChange() {
        notifyElapsedTimeChanged()
        if let currentItem = currentlyPlaying?.playable {
            savePlayInformation(of: currentItem)
            updateNowPlayingInfo(playable: currentItem)
        }
    }
    
    private func savePlayInformation(of playable: AbstractPlayable) {
        let playDuration = backendAudioPlayer.duration
        let playProgress = backendAudioPlayer.elapsedTime
        if playDuration != 0.0, playProgress != 0.0, playable == currentlyPlaying?.playable {
            playable.playDuration = Int(playDuration)
            if playProgress > Self.progressTimeStartThreshold, playProgress < (playDuration - Self.progressTimeEndThreshold) {
                playable.playProgress = Int(playProgress)
            } else {
                playable.playProgress = 0
            }
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
        guard let currentItem = currentlyPlaying?.playable, let remoteCommandCenter = remoteCommandCenter else { return }
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
