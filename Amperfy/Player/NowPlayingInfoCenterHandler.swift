import Foundation
import MediaPlayer

class NowPlayingInfoCenterHandler {
    
    private let musicPlayer: MusicPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter

    init(musicPlayer: MusicPlayer, backendAudioPlayer: BackendAudioPlayer, nowPlayingInfoCenter: MPNowPlayingInfoCenter) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.nowPlayingInfoCenter = nowPlayingInfoCenter
    }
    
    func updateNowPlayingInfo(playable: AbstractPlayable) {
        let albumTitle = playable.asSong?.album?.name ?? ""
        nowPlayingInfoCenter.nowPlayingInfo = [
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

}

extension NowPlayingInfoCenterHandler: MusicPlayable {
    func didStartPlaying() {
        if let curPlayable = backendAudioPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didPause() {
        if let curPlayable = backendAudioPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didStopPlaying() { }
    
    func didElapsedTimeChange() {
        if let curPlayable = backendAudioPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didPlaylistChange() { }
    
    func didArtworkChange() { }
}
