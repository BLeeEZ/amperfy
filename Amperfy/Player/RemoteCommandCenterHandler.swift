import Foundation
import MediaPlayer

class RemoteCommandCenterHandler {
    
    private let musicPlayer: MusicPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let remoteCommandCenter: MPRemoteCommandCenter

    init(musicPlayer: MusicPlayer, backendAudioPlayer: BackendAudioPlayer, remoteCommandCenter: MPRemoteCommandCenter) {
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
            self.musicPlayer.togglePlay()
            return .success})
        
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.addTarget(handler: { (event) in
            self.musicPlayer.playPreviousOrReplay()
            return .success})

        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.addTarget(handler: { (event) in
            self.musicPlayer.playNext()
            return .success})
        
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.addTarget(handler: { (event) in
            guard let command = event as? MPChangePlaybackPositionCommandEvent else { return .noSuchContent}
            self.backendAudioPlayer.seek(toSecond: command.positionTime)
            return .success})
        
        remoteCommandCenter.skipBackwardCommand.isEnabled = true
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [15]
        remoteCommandCenter.skipBackwardCommand.addTarget(handler: { (event) in
            guard let command = event.command as? MPSkipIntervalCommand else { return .noSuchContent }
            let interval = Double(truncating: command.preferredIntervals[0])
            self.backendAudioPlayer.seek(toSecond: self.backendAudioPlayer.elapsedTime - interval)
            return .success})
        
        remoteCommandCenter.skipForwardCommand.isEnabled = true
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [30]
        remoteCommandCenter.skipForwardCommand.addTarget(handler: { (event) in
            guard let command = event.command as? MPSkipIntervalCommand else { return .noSuchContent }
            let interval = Double(truncating: command.preferredIntervals[0])
            self.backendAudioPlayer.seek(toSecond: self.backendAudioPlayer.elapsedTime + interval)
            return .success})
    }

    private func changeRemoteCommandCenterControlsBasedOnCurrentPlayableType() {
        guard let currentItem = musicPlayer.currentlyPlaying else { return }
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

extension RemoteCommandCenterHandler: MusicPlayable {
    func didStartPlaying() {
        changeRemoteCommandCenterControlsBasedOnCurrentPlayableType()
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
