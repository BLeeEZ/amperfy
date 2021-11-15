import Foundation

class PopupPlaylistGrouper {
    
    var sections: [[AbstractPlayable]]
    let sectionNames = ["Previous", "Waiting Queue", "Next"]
    var playIndex: Int
    let isWaitingQueueVisible: Bool
    let isWaitingQueuePlaying: Bool
    
    init(player: MusicPlayer) {
        playIndex = player.currentContextPlaylistIndex
        isWaitingQueuePlaying = player.isWaitingQueuePlaying
        isWaitingQueueVisible = player.waitingQueue.songCount > 0 && !(player.isWaitingQueuePlaying && player.waitingQueue.songCount == 1)
        
        let playlist = player.playlist
        var played = [AbstractPlayable]()
        if playIndex == 0, playlist.songCount > 0, isWaitingQueuePlaying {
            played = [playlist.playables[0]]
        } else if playIndex > 0 {
            if isWaitingQueuePlaying {
                played = Array(playlist.playables[0...playIndex])
            } else {
                played = Array(playlist.playables[0...playIndex-1])
            }
        }
        var next = [AbstractPlayable]()
        if playlist.playables.count > 0, playIndex < playlist.playables.count-1 {
            next = Array(playlist.playables[(playIndex+1)...])
        }
        var waitingQueue = [AbstractPlayable]()
        if isWaitingQueueVisible {
            if isWaitingQueuePlaying {
                waitingQueue = Array(player.waitingQueue.playables[1...])
            } else {
                waitingQueue = player.waitingQueue.playables
            }
        }
        sections = [played, waitingQueue, next]
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
    
    func convertIndexPathToPlayerIndex(indexPath: IndexPath) -> PlayerIndex {
        var queueType = PlayerQueueType.playlist
        var playlistIndex = indexPath.row
        if indexPath.section == 1 {
            queueType = .waitingQueue
            if isWaitingQueuePlaying {
                playlistIndex += 1
            }
        }
        if indexPath.section == 2 {
            playlistIndex += sections[0].count
            if !isWaitingQueuePlaying {
                playlistIndex += 1
            }
        }
        return PlayerIndex(queueType: queueType, index: playlistIndex)
    }
    
    func convertPlayerIndexToIndexPath(playerIndex: PlayerIndex) -> IndexPath? {
        if !isWaitingQueuePlaying, playerIndex.index == playIndex {
            return nil
        }
        if playerIndex.queueType == .waitingQueue {
            return IndexPath(row: playerIndex.index, section: 1)
        } else {
            if playerIndex.index < playIndex {
                return IndexPath(row: playerIndex.index, section: 0)
            } else {
                if isWaitingQueuePlaying {
                    return IndexPath(row: playerIndex.index-playIndex, section: 2)
                } else {
                    return IndexPath(row: playerIndex.index-playIndex-1, section: 2)
                }
            }
        }
    }
    
}
