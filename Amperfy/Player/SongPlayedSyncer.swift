import Foundation

class SongPlayedSyncer  {
    
    private static let minimumPlaytimeTillSyncedAsPlayedToServerInSec: UInt32 = 5
    
    private let persistentStorage: PersistentStorage
    private let musicPlayer: MusicPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let backendApi: BackendApi

    init(persistentStorage: PersistentStorage, musicPlayer: MusicPlayer, backendAudioPlayer: BackendAudioPlayer, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.backendApi = backendApi
    }
    
    private func syncSongPlayed() {
        guard let curPlaying = musicPlayer.currentlyPlaying, let curPlayingSong = curPlaying.asSong else { return }
        DispatchQueue.global().async {
            sleep(Self.minimumPlaytimeTillSyncedAsPlayedToServerInSec)
            DispatchQueue.main.async {
                guard curPlaying == self.musicPlayer.currentlyPlaying, self.backendAudioPlayer.playType == .cache else { return }
                self.syncSongPlayedToServer(playedSong: curPlayingSong)
            }
        }
    }
    
    private func syncSongPlayedToServer(playedSong: Song) {
        guard persistentStorage.settings.isOnlineMode else { return }
        persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.backendApi.createLibrarySyncer()
            let songMO = try! context.existingObject(with: playedSong.managedObject.objectID) as! SongMO
            let song = Song(managedObject: songMO)
            syncer.recordPlay(song: song)
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
