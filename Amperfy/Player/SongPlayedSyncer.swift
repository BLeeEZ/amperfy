import Foundation

class SongPlayedSyncer  {
    
    private static let minimumPlaytimeTillSyncedAsPlayedToServerInSec: UInt32 = 5
    
    private let musicPlayer: MusicPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let scrobbleSyncer: ScrobbleSyncer

    init(musicPlayer: MusicPlayer, backendAudioPlayer: BackendAudioPlayer, scrobbleSyncer: ScrobbleSyncer) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.scrobbleSyncer = scrobbleSyncer
    }
    
    private func syncSongPlayed() {
        guard let curPlaying = musicPlayer.currentlyPlaying, let curPlayingSong = curPlaying.asSong else { return }
        DispatchQueue.global().async {
            sleep(Self.minimumPlaytimeTillSyncedAsPlayedToServerInSec)
            DispatchQueue.main.async {
                guard self.backendAudioPlayer.isPlaying, curPlaying == self.musicPlayer.currentlyPlaying, self.backendAudioPlayer.playType == .cache else { return }
                self.scrobbleSyncer.scrobble(playedSong: curPlayingSong)
            }
        }
    }

}

extension SongPlayedSyncer: MusicPlayable {
    func didStartPlaying() {
        syncSongPlayed()
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
