import Foundation
import AVFoundation
import MediaPlayer
import os.log

protocol MusicPlayable {
    func didStartedPlaying(playlistElement: PlaylistElement)
    func didStartedPausing()
    func didStopped(playlistElement: PlaylistElement?)
    func didElapsedTimeChanged()
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
}

class Player: NSObject, AmpacheRespondable {
    
    var playlist: Playlist { 
        return coreData.playlist
    }
    var isPlaying: Bool {
        return ampachePlayer.isPlaying
    }
    var currentlyPlaying: PlaylistElement? {
        if let playingSong = ampachePlayer.currentlyPlaying {
            return playingSong
        }
        return coreData.currentPlaylistElement
    }
    var elapsedTime: Double {
        return ampachePlayer.elapsedTime
    }
    var duration: Double {
        return ampachePlayer.duration
    }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter?
    var isShuffel: Bool {
        get { return coreData.isShuffel }
        set { coreData.isShuffel = newValue }
    }
    var repeatMode: RepeatMode {
        get { return coreData.repeatMode }
        set { coreData.repeatMode = newValue }
    }

    private var coreData: PlayerData
    private let ampachePlayer: AmpachePlayer
    private var notifierList = [MusicPlayable]()
    private let currentSongReplayInsteadPlayPreviousTimeInSec = 5.0
    
    init(coreData: PlayerData, ampachePlayer: AmpachePlayer) {
        self.coreData = coreData
        self.ampachePlayer = ampachePlayer
        super.init()
        self.ampachePlayer.responder = self
    }

    func reinit(coreData: PlayerData) {
        self.coreData = coreData
    }

    private func shouldCurrentSongReplayInsteadPlayPrevious() -> Bool {
        if !ampachePlayer.canBeContinued {
            return false
        }
        return ampachePlayer.elapsedTime >= currentSongReplayInsteadPlayPreviousTimeInSec
    }

    private func replayCurrenSong() {
        os_log(.debug, "Replay song")
        seek(toSecond: 0)
    }

    func seek(toSecond: Double) {
        ampachePlayer.seek(toSecond: toSecond)
        ampachePlayer.continuePlay()
    }
    
    func addToPlaylist(song: Song) {
        playlist.append(song: song)
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        coreData.movePlaylistSong(fromIndex: fromIndex, to: to)
    }
    
    func removeFromPlaylist(at index: Int) {
        guard index < playlist.songs.count else { return }
        let toBeRemovedSong = playlist.songs[index]
        if toBeRemovedSong == coreData.currentSong {
            playNext()
        }
        coreData.removeSongFromPlaylist(at: index)
    }
    
    private func prepareSongAndInsertToPlayer(playlistIndex: Int, reactionToError: FetchErrorReaction) {
        guard playlistIndex < playlist.songs.count else { return }
        let playlistEntry = playlist.entries[playlistIndex]
        ampachePlayer.requestToPlay(playlistEntry: playlistEntry, reactionToError: reactionToError)
        coreData.currentSongIndex = playlistIndex
    }
    
    func notifySongPreparationFinished() {
        if let curPlaylistElement = ampachePlayer.currentlyPlaying {
            notifySongStartedPlaying(playlistElement: curPlaylistElement)
            if let song = curPlaylistElement.song {
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
        if !ampachePlayer.canBeContinued {
            play(songInPlaylistAt: coreData.currentSongIndex)
        } else {
            ampachePlayer.continuePlay()
        }
    }
    
    func play(song: Song) {
        cleanPlaylist()
        addToPlaylist(song: song)
        play(songInPlaylistAt: coreData.currentSongIndex)
    }
    
    func play(songInPlaylistAt: Int, reactionToError: FetchErrorReaction = .playNext) {
        if songInPlaylistAt <= playlist.songs.count {
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
        if isShuffel {
            play(songInPlaylistAt: playlist.randomSongIndex)
        } else if let nextSongIndex = coreData.nextSongIndex {
            play(songInPlaylistAt: nextSongIndex)
        } else if repeatMode == .all, !playlist.songs.isEmpty {
            play(songInPlaylistAt: 0)
        } else {
            stop()
        }
    }
    
    func playNextCached() {
        if isShuffel, let nextSongIndex = playlist.randomCachedSongIndex {
            play(songInPlaylistAt: nextSongIndex)
        } else if let nextSongIndex = playlist.nextCachedSongIndex(upwardsFrom: coreData.currentSongIndex) {
            play(songInPlaylistAt: nextSongIndex)
        } else if repeatMode == .all, let nextSongIndex = playlist.nextCachedSongIndex(beginningAt: 0) {
            play(songInPlaylistAt: nextSongIndex)
        } else {
            stop()
        }
    }
    
    func pause() {
        ampachePlayer.pause()
        notifySongPaused()
        if let song = coreData.currentSong {
            updateNowPlayingInfo(song: song)
        }
    }
    
    func stop() {
        notifyPlayerStopped(playlistElement: currentlyPlaying)
        ampachePlayer.stop()
        coreData.currentSongIndex = 0
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
    
    func notifySongStartedPlaying(playlistElement: PlaylistElement) {
        for notifier in notifierList {
            notifier.didStartedPlaying(playlistElement: playlistElement)
        }
    }
    
    func notifySongPaused() {
        for notifier in notifierList {
            notifier.didStartedPausing()
        }
    }
    
    func notifyPlayerStopped(playlistElement: PlaylistElement?) {
        for notifier in notifierList {
            notifier.didStopped(playlistElement: playlistElement)
        }
    }
    
    func didElapsedTimeChanged() {
        notifyElapsedTimeChanged()
    }
    
    func notifyElapsedTimeChanged() {
        for notifier in notifierList {
            notifier.didElapsedTimeChanged()
        }
    }

    func updateNowPlayingInfo(song: Song) {
        nowPlayingInfoCenter?.nowPlayingInfo = [
            MPMediaItemPropertyTitle: song.title ?? "",
            MPMediaItemPropertyAlbumTitle: song.album?.name ?? "",
            MPMediaItemPropertyArtist: song.artist?.name ?? "",
            MPMediaItemPropertyPlaybackDuration: ampachePlayer.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: ampachePlayer.elapsedTime,
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
                    if let curPlaying = currentlyPlaying {
                        os_log(.info, "Audio interruption ended -> Resume playing")
                        play()
                        notifySongStartedPlaying(playlistElement: curPlaying)
                    }
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
