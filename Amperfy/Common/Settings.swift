import Foundation

class Settings {

    var songActionOnTab: SongActionOnTab
    var playerDisplayStyle: PlayerDisplayStyle

    init(songActionOnTab: SongActionOnTab, playerDisplayStyle: PlayerDisplayStyle) {
        self.songActionOnTab = songActionOnTab
        self.playerDisplayStyle = playerDisplayStyle
    }

}

