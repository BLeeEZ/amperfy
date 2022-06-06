import Foundation
import MediaPlayer

class NowPlayingInfoCenterHandler {
    
    private let musicPlayer: AudioPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let persistentStorage: PersistentStorage
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter

    init(musicPlayer: AudioPlayer, backendAudioPlayer: BackendAudioPlayer, nowPlayingInfoCenter: MPNowPlayingInfoCenter, persistentStorage: PersistentStorage) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.nowPlayingInfoCenter = nowPlayingInfoCenter
        self.persistentStorage = persistentStorage
    }

    func updateNowPlayingInfo(playable: AbstractPlayable) {
        let albumTitle = playable.asSong?.album?.name ?? ""
        nowPlayingInfoCenter.nowPlayingInfo = [
            MPMediaItemPropertyIsCloudItem: !playable.isCached,
            MPMediaItemPropertyTitle: playable.title,
            MPMediaItemPropertyAlbumTitle: albumTitle,
            MPMediaItemPropertyArtist: playable.creatorName,
            MPMediaItemPropertyPlaybackDuration: backendAudioPlayer.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: backendAudioPlayer.elapsedTime,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork.init(boundsSize: playable.image(setting: persistentStorage.settings.artworkDisplayPreference).size, requestHandler: { (size) -> UIImage in
                return playable.image(setting: self.persistentStorage.settings.artworkDisplayPreference)
            })
        ]
    }

}

extension NowPlayingInfoCenterHandler: MusicPlayable {
    func didStartPlaying() {
        if let curPlayable = musicPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didPause() {
        if let curPlayable = musicPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
        nowPlayingInfoCenter.nowPlayingInfo = [:]
    }
    
    func didStopPlaying() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }
    
    func didElapsedTimeChange() {
        if let curPlayable = musicPlayer.currentlyPlaying {
            updateNowPlayingInfo(playable: curPlayable)
        }
    }
    
    func didPlaylistChange() { }
    
    func didArtworkChange() { }
}
