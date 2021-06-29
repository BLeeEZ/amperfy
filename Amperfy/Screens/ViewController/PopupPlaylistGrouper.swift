import Foundation

class PopupPlaylistGrouper {
    
    let sectionNames = ["Previous", "Next"]
    var sections: [[AbstractPlayable]]
    private var playIndex: Int
    
    init(player: MusicPlayer) {
        playIndex = player.currentlyPlaying?.index ?? 0
        
        let playlist = player.playlist
        var played = [AbstractPlayable]()
        if playIndex > 0 {
            played = Array(playlist.playables[0...playIndex-1])
        }
        var next = [AbstractPlayable]()
        if playlist.playables.count > 0, playIndex < playlist.playables.count-1 {
            next = Array(playlist.playables[(playIndex+1)...])
        }
        sections = [played, next]
    }
    
    var beforeCurrentlyPlayingtIndexPath: IndexPath? {
        if sections[0].count > 0 {
            return IndexPath(row: sections[0].count-1, section: 0)
        } else {
            return nil
        }
    }
    
    var nextPlayingtIndexPath: IndexPath? {
        if sections[1].count > 0 {
            return IndexPath(row: 0, section: 1)
        } else if sections[0].count > 0 {
            return IndexPath(row: sections[0].count-1, section: 0)
        } else {
            return nil
        }
    }
    
    var afterNextPlayingtIndexPath: IndexPath? {
        if sections[1].count > 1 {
            return IndexPath(row: 1, section: 1)
        } else {
            return nil
        }
    }
    
    func convertIndexPathToPlaylistIndex(indexPath: IndexPath) -> Int {
        var playlistIndex = indexPath.row
        if indexPath.section == 1 {
            playlistIndex += (1 + sections[0].count)
        }
        return playlistIndex
    }
    
    func convertPlaylistIndexToIndexPath(playlistIndex: Int) -> IndexPath? {
        if playlistIndex == playIndex {
            return nil
        }
        if playlistIndex < playIndex {
            return IndexPath(row: playlistIndex, section: 0)
        } else {
            return IndexPath(row: playlistIndex-playIndex-1, section: 1)
        }
    }
    
}
