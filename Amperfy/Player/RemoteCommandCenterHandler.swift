import Foundation
import MediaPlayer

class RemoteCommandCenterHandler {
    
    private var musicPlayer: PlayerFacade
    private let backendAudioPlayer: BackendAudioPlayer
    private let remoteCommandCenter: MPRemoteCommandCenter

    init(musicPlayer: PlayerFacade, backendAudioPlayer: BackendAudioPlayer, remoteCommandCenter: MPRemoteCommandCenter) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.remoteCommandCenter = remoteCommandCenter
    }
    
    func configureRemoteCommands() {
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.playCommand.addTarget(handler: { (event) in
            self.musicPlayer.play()
            return .success})
        
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.addTarget(handler: { (event) in
            self.musicPlayer.pause()
            return .success})
        
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.addTarget(handler: { (event) in
            self.musicPlayer.togglePlayPause()
            return .success})
        
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.addTarget(handler: { (event) in
            self.musicPlayer.playPreviousOrReplay()
            return .success})

        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.addTarget(handler: { (event) in
            self.musicPlayer.playNext()
            return .success})
        
        remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
        remoteCommandCenter.changeRepeatModeCommand.addTarget(handler: { (event) in
            guard let command = event as? MPChangeRepeatModeCommandEvent else { return .noSuchContent}
            self.musicPlayer.setRepeatMode(RepeatMode.fromMPRepeatType(type: command.repeatType))
            return .success})

        remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
        remoteCommandCenter.changeShuffleModeCommand.addTarget(handler: { (event) in
            guard let command = event as? MPChangeShuffleModeCommandEvent else { return .noSuchContent}
            if (command.shuffleType == .off && self.musicPlayer.isShuffle) ||
               (command.shuffleType != .off && !self.musicPlayer.isShuffle) {
            }
            self.musicPlayer.toggleShuffle()
            return .success })

        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.addTarget(handler: { (event) in
            guard let command = event as? MPChangePlaybackPositionCommandEvent else { return .noSuchContent}
            self.backendAudioPlayer.seek(toSecond: command.positionTime)
            return .success})
        
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: self.musicPlayer.skipBackwardInterval)]
        remoteCommandCenter.skipBackwardCommand.addTarget(handler: { (event) in
            self.musicPlayer.skipBackward()
            return .success})
        
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value:  self.musicPlayer.skipForwardInterval)]
        remoteCommandCenter.skipForwardCommand.addTarget(handler: { (event) in
            self.musicPlayer.skipForward()
            return .success})
    }

    private func changeRemoteCommandCenterControlsBasedOnCurrentPlayableType() {
        guard let currentItem = musicPlayer.currentlyPlaying else { return }
        if currentItem.isSong {
            remoteCommandCenter.previousTrackCommand.isEnabled = true
            remoteCommandCenter.nextTrackCommand.isEnabled = true
            remoteCommandCenter.skipBackwardCommand.isEnabled = false
            remoteCommandCenter.skipForwardCommand.isEnabled = false
            remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
            remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
        } else if currentItem.isPodcastEpisode {
            remoteCommandCenter.previousTrackCommand.isEnabled = false
            remoteCommandCenter.nextTrackCommand.isEnabled = false
            remoteCommandCenter.skipBackwardCommand.isEnabled = true
            remoteCommandCenter.skipForwardCommand.isEnabled = true
            remoteCommandCenter.changeShuffleModeCommand.isEnabled = false
            remoteCommandCenter.changeRepeatModeCommand.isEnabled = false
        }
        updateShuffle()
        updateRepeat()
    }
    
    private func updateShuffle() {
        remoteCommandCenter.changeShuffleModeCommand.currentShuffleType = musicPlayer.isShuffle ? .items : .off
    }

    private func updateRepeat() {
        remoteCommandCenter.changeRepeatModeCommand.currentRepeatType = musicPlayer.repeatMode.asMPRepeatType
    }

}

extension RemoteCommandCenterHandler: MusicPlayable {
    func didStartPlaying() {
        changeRemoteCommandCenterControlsBasedOnCurrentPlayableType()
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
    
    func didShuffleChange() {
        updateShuffle()
    }
    
    func didRepeatChange() {
        updateRepeat()
    }
}
