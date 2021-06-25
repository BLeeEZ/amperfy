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
    
    var playlist: Playlist { 
        return coreData.playlist
    }
    var isPlaying: Bool {
        return backendAudioPlayer.isPlaying
    }
    var currentlyPlaying: PlaylistItem? {
        if let playingSong = backendAudioPlayer.currentlyPlaying {
            return playingSong
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
    var isAutoCachePlayedSong: Bool {
        get { return coreData.isAutoCachePlayedSong }
        set {
            coreData.isAutoCachePlayedSong = newValue
            backendAudioPlayer.isAutoCachePlayedSong = newValue
        }
    }

    private var coreData: PlayerData
    private var songDownloadManager: DownloadManageable
    private let backendAudioPlayer: BackendAudioPlayer
    private let userStatistics: UserStatistics
    private var notifierList = [MusicPlayable]()
    private let currentSongReplayInsteadPlayPreviousTimeInSec = 5.0
    
    init(coreData: PlayerData, songDownloadManager: DownloadManageable, backendAudioPlayer: BackendAudioPlayer, userStatistics: UserStatistics) {
        self.coreData = coreData
        self.songDownloadManager = songDownloadManager
        self.backendAudioPlayer = backendAudioPlayer
        self.backendAudioPlayer.isAutoCachePlayedSong = coreData.isAutoCachePlayedSong
        self.userStatistics = userStatistics
        super.init()
        self.backendAudioPlayer.responder = self
    }

    func reinit(coreData: PlayerData) {
        self.coreData = coreData
    }

    private func shouldCurrentSongReplayInsteadPlayPrevious() -> Bool {
        if !backendAudioPlayer.canBeContinued {
            return false
        }
        return backendAudioPlayer.elapsedTime >= currentSongReplayInsteadPlayPreviousTimeInSec
    }

    private func replayCurrenSong() {
        os_log(.debug, "Replay song")
        seek(toSecond: 0)
        play()
    }

    func seek(toSecond: Double) {
        userStatistics.usedAction(.playerSeek)
        backendAudioPlayer.seek(toSecond: toSecond)
    }
    
    func addToPlaylist(song: Song) {
        coreData.addToPlaylist(song: song)
    }
    
    func addToPlaylist(songs: [Song]) {
        coreData.addToPlaylist(songs: songs)
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        coreData.movePlaylistSong(fromIndex: fromIndex, to: to)
    }
    
    func removeFromPlaylist(at index: Int) {
        guard index < playlist.songs.count else { return }
        if playlist.songs.count <= 1 {
            stop()
        } else if index == coreData.currentSongIndex {
            playNext()
        }
        coreData.removeSongFromPlaylist(at: index)
    }
    
    private func prepareSongAndInsertToPlayer(playlistIndex: Int, reactionToError: FetchErrorReaction) {
        guard playlistIndex < playlist.songs.count else { return }
        let playlistItem = playlist.items[playlistIndex]
        userStatistics.playedSong(repeatMode: repeatMode, isShuffle: isShuffle)
        backendAudioPlayer.requestToPlay(playlistItem: playlistItem, reactionToError: reactionToError)
        coreData.currentSongIndex = playlistIndex
        preDownloadNextSongs(playlistIndex: playlistIndex)
    }
    
    private func preDownloadNextSongs(playlistIndex: Int) {
        guard coreData.isAutoCachePlayedSong else { return }
        var nextSongsCount = (playlist.songs.count-1) - playlistIndex
        if nextSongsCount > Self.preDownloadCount {
            nextSongsCount = Self.preDownloadCount
        }
        if nextSongsCount > 0 {
            for i in 1...nextSongsCount {
                let nextSongIndex = playlistIndex + i
                if let song = playlist.items[nextSongIndex].song, !song.isCached {
                    songDownloadManager.download(object: song, notifier: nil, priority: .high)
                }
            }
        }
    }
    
    func notifySongPreparationFinished() {
        if let curPlaylistItem = backendAudioPlayer.currentlyPlaying {
            notifySongStartedPlaying(playlistItem: curPlaylistItem)
            if let song = curPlaylistItem.song {
                updateNowPlayingInfo(song: song)
            }
        }
    }
    
    func didSongFinishedPlaying() {
        if repeatMode == .single {
            replayCurrenSong()
        } else {
            playNext()
        }
    }
    
    func play() {
        if !backendAudioPlayer.canBeContinued {
            play(songInPlaylistAt: coreData.currentSongIndex)
        } else {
            backendAudioPlayer.continuePlay()
            if let curPlaylistItem = backendAudioPlayer.currentlyPlaying {
                notifySongStartedPlaying(playlistItem: curPlaylistItem)
            }
        }
    }
    
    func play(song: Song) {
        cleanPlaylist()
        addToPlaylist(song: song)
        play(songInPlaylistAt: coreData.currentSongIndex)
    }
    
    func play(songInPlaylistAt: Int, reactionToError: FetchErrorReaction = .playNext) {
        if songInPlaylistAt >= 0, songInPlaylistAt <= playlist.songs.count {
            prepareSongAndInsertToPlayer(playlistIndex: songInPlaylistAt, reactionToError: reactionToError)
        } else {
            stop()
        }
    }
    
    func playPreviousOrReplay() {
        if shouldCurrentSongReplayInsteadPlayPrevious() {
            replayCurrenSong()
        } else {
            playPrevious()
        }
    }

    func playPrevious() {
        if let prevSongIndex = coreData.previousSongIndex {
            play(songInPlaylistAt: prevSongIndex, reactionToError: .playPrevious) 
        } else if repeatMode == .all, !playlist.songs.isEmpty {
            play(songInPlaylistAt: playlist.lastSongIndex, reactionToError: .playPrevious)
        } else if !playlist.songs.isEmpty {
            play(songInPlaylistAt: 0, reactionToError: .playPrevious)
        } else {
            stop()
        }
    }

    func playPreviousCached() {
        if let prevSongIndex = playlist.previousCachedSongIndex(downwardsFrom: coreData.currentSongIndex) {
            play(songInPlaylistAt: prevSongIndex, reactionToError: .playPrevious)
        } else if repeatMode == .all, let prevSongIndex = playlist.previousCachedSongIndex(beginningAt: playlist.lastSongIndex) {
            play(songInPlaylistAt: prevSongIndex, reactionToError: .playPrevious)
        } else {
            stop()
        }
    }
    
    func playNext() {
        if let nextSongIndex = coreData.nextSongIndex {
            play(songInPlaylistAt: nextSongIndex)
        } else if repeatMode == .all, !playlist.songs.isEmpty {
            play(songInPlaylistAt: 0)
        } else {
            stop()
        }
    }
    
    func playNextCached() {
        if let nextSongIndex = playlist.nextCachedSongIndex(upwardsFrom: coreData.currentSongIndex) {
            play(songInPlaylistAt: nextSongIndex)
        } else if repeatMode == .all, let nextSongIndex = playlist.nextCachedSongIndex(beginningAt: 0) {
            play(songInPlaylistAt: nextSongIndex)
        } else {
            stop()
        }
    }
    
    func pause() {
        backendAudioPlayer.pause()
        notifySongPaused()
        if let song = coreData.currentSong {
            updateNowPlayingInfo(song: song)
        }
    }
    
    func stop() {
        let stoppedPlaylistItem = currentlyPlaying
        backendAudioPlayer.stop()
        coreData.currentSongIndex = 0
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
        coreData.removeAllSongs()
    }
    
    func addNotifier(notifier: MusicPlayable) {
        notifierList.append(notifier)
    }
    
    func removeAllNotifier() {
        notifierList.removeAll()
    }
    
    func notifySongStartedPlaying(playlistItem: PlaylistItem) {
        for notifier in notifierList {
            notifier.didStartPlaying(playlistItem: playlistItem)
        }
    }
    
    func notifySongPaused() {
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

    func updateNowPlayingInfo(song: Song) {       
        nowPlayingInfoCenter?.nowPlayingInfo = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyAlbumTitle: song.album?.name ?? "",
            MPMediaItemPropertyArtist: song.creatorName,
            MPMediaItemPropertyPlaybackDuration: backendAudioPlayer.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: backendAudioPlayer.elapsedTime,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork.init(boundsSize: song.image.size, requestHandler: { (size) -> UIImage in
                return song.image
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
    
    func configureRemoteCommands(commandCenter: MPRemoteCommandCenter) {
        commandCenter.playCommand.isEnabled = true;
        commandCenter.playCommand.addTarget(handler: { (event) in
            self.play()
            return .success})
        
        commandCenter.pauseCommand.isEnabled = true;
        commandCenter.pauseCommand.addTarget(handler: { (event) in
            self.pause()
            return .success})
        
        commandCenter.togglePlayPauseCommand.isEnabled = true;
        commandCenter.togglePlayPauseCommand.addTarget(handler: { (event) in
            self.togglePlay()
            return .success})
        
        commandCenter.previousTrackCommand.isEnabled = true;
        commandCenter.previousTrackCommand.addTarget(handler: { (event) in
            self.playPreviousOrReplay()
            return .success})

        commandCenter.nextTrackCommand.isEnabled = true;
        commandCenter.nextTrackCommand.addTarget(handler: { (event) in
            self.playNext()
            return .success})
    }

}
