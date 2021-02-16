import Foundation

class Settings {

    var songActionOnTab: SongActionOnTab

    init() {
        self.songActionOnTab = .addToPlaylistAndPlay
    }

    init(songActionOnTab: SongActionOnTab) {
        self.songActionOnTab = songActionOnTab
    }

}

