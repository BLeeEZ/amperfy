import Foundation
import UIKit

class EmbeddedArtworkExtractor  {
    
    private static let waitTimeTillCheckAgainIfPlayableIsLoadedInSec: UInt32 = 3
    
    private let musicPlayer: MusicPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let library: LibraryStorage

    init(musicPlayer: MusicPlayer, backendAudioPlayer: BackendAudioPlayer, library: LibraryStorage) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.library = library
    }
    
    private func extractEmbeddedArtwork() {
        guard let playable = musicPlayer.currentlyPlaying, playable.embeddedArtwork == nil else { return }
        // Wait some time till the playable is loaded and the embedded arwork if existing, can be extracted
        DispatchQueue.global().async {
            sleep(Self.waitTimeTillCheckAgainIfPlayableIsLoadedInSec)
            DispatchQueue.main.async {
                guard playable == self.musicPlayer.currentlyPlaying,
                      self.backendAudioPlayer.isPlayableLoaded,
                      let embeddedImage = self.backendAudioPlayer.getEmbeddedArtworkFromID3Tag() else {
                    return
                }
                self.saveEmbeddedImageInLibrary(playable: playable, embeddedImage: embeddedImage)
            }
        }
    }
    
    private func saveEmbeddedImageInLibrary(playable: AbstractPlayable, embeddedImage: UIImage) {
        let embeddedArtwork = library.createEmbeddedArtwork()
        embeddedArtwork.setImage(fromData: embeddedImage.pngData())
        embeddedArtwork.owner = playable
        library.saveContext()
        musicPlayer.notifyArtworkChanged()
    }

}

extension EmbeddedArtworkExtractor: MusicPlayable {
    func didStartPlaying() {
        extractEmbeddedArtwork()
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
