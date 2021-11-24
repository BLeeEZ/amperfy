import Foundation

public class PlayQueueHandler  {
    
    private var playerQueues: PlayerQueuesPersistent
    
    init(playerData: PlayerQueuesPersistent) {
        self.playerQueues = playerData
    }
    
    var currentlyPlaying: AbstractPlayable? {
        return playerQueues.currentItem
    }
    
    var prevQueue: [AbstractPlayable] {
        var played = [AbstractPlayable]()
        if isWaitingQueuePlaying, currentIndex == -1 {
            // prev is empty
        } else if isWaitingQueuePlaying, currentIndex == 0, playlist.songCount > 0 {
            played = [playlist.playables[0]]
        } else if currentIndex > 0 {
            if isWaitingQueuePlaying {
                played = Array(playlist.playables[0...currentIndex])
            } else {
                played = Array(playlist.playables[0...currentIndex-1])
            }
        }
        return played
    }
    
    var waitingQueue: [AbstractPlayable] {
        var waitingQueue = [AbstractPlayable]()
        if isWaitingQueueVisible {
            if isWaitingQueuePlaying {
                waitingQueue = Array(waitingQueuePlaylist.playables[1...])
            } else {
                waitingQueue = waitingQueuePlaylist.playables
            }
        }
        return waitingQueue
    }
    
    var nextQueue: [AbstractPlayable] {
        if playlist.playables.count > 0, currentIndex < playlist.playables.count-1 {
            return Array(playlist.playables[(currentIndex+1)...])
        } else {
            return [AbstractPlayable]()
        }
    }
    
    var isWaitingQueuePlaying: Bool {
        return playerQueues.isWaitingQueuePlaying
    }
    
    func addToPlaylist(playable: AbstractPlayable) {
        playerQueues.addToPlaylist(playable: playable)
    }
    
    func addToPlaylist(playables: [AbstractPlayable]) {
        playerQueues.addToPlaylist(playables: playables)
    }
    
    func addToWaitingQueue(playable: AbstractPlayable) {
        playerQueues.addToWaitingQueue(playable: playable)
    }
    
    func clearPlaylistQueues() {
        playerQueues.clearPlaylistQueues()
    }
    
    func clearWaitingQueue() {
        if isWaitingQueuePlaying, let currentWaitingQueueItem = currentlyPlaying {
            playerQueues.clearWaitingQueue()
            addToWaitingQueue(playable: currentWaitingQueueItem)
        } else {
            playerQueues.clearWaitingQueue()
        }
    }
    
    func removeAllItems() {
        playerQueues.removeAllItems()
    }

    func markAndGetPlayableAsPlaying(at playerIndex: PlayerIndex) -> AbstractPlayable? {
        var playable: AbstractPlayable?
        if playerIndex.queueType == .waitingQueue, playerIndex.index >= 0, playerIndex.index < waitingQueue.count {
            playable = waitingQueue[playerIndex.index]
            if isWaitingQueuePlaying {
                removeItemFromWaitingQueue(at: 0)
            }
            if playerIndex.index > 0 {
                for _ in 1...playerIndex.index {
                    removeItemFromWaitingQueue(at: 0)
                }
            }
            playerQueues.isWaitingQueuePlaying = true
        } else if playerIndex.queueType == .prev, playerIndex.index >= 0, playerIndex.index < prevQueue.count {
            if isWaitingQueuePlaying {
                removeItemFromWaitingQueue(at: 0)
            }
            playable = prevQueue[playerIndex.index]
            currentIndex = playerIndex.index
            playerQueues.isWaitingQueuePlaying = false
        } else if playerIndex.queueType == .next, playerIndex.index >= 0, playerIndex.index < nextQueue.count {
            if isWaitingQueuePlaying {
                removeItemFromWaitingQueue(at: 0)
            }
            playable = nextQueue[playerIndex.index]
            if isWaitingQueuePlaying {
                currentIndex = prevQueue.count + playerIndex.index
            } else {
                currentIndex = prevQueue.count + 1 + playerIndex.index
            }
            playerQueues.isWaitingQueuePlaying = false
        }
        return playable
    }
    
    func removePlayable(at: PlayerIndex) {
        switch(at.queueType) {
        case .waitingQueue:
            if isWaitingQueuePlaying {
                removeItemFromWaitingQueue(at: at.index+1)
            } else {
                removeItemFromWaitingQueue(at: at.index)
            }
        case .prev:
            removeItemFromPlaylist(at: at.index)
        case .next:
            var playlistIndex = prevQueue.count + at.index
            if !isWaitingQueuePlaying {
                playlistIndex += 1
            }
            removeItemFromPlaylist(at: playlistIndex)
        }
    }
    
    func movePlayable(from: PlayerIndex, to: PlayerIndex) {
        let waitingQueueOffsetIsWaitingQueuePlaying = isWaitingQueuePlaying ? 1 : 0
        let nextQueueOffsetIsWaitingQueuePlaying = isWaitingQueuePlaying ? 0 : 1
        let offsetToNext = prevQueue.count + nextQueueOffsetIsWaitingQueuePlaying
        
        guard from.index >= 0, to.index >= 0 else { return }
        
        if from.queueType == .prev { guard from.index < prevQueue.count else { return } }
        if from.queueType == .waitingQueue { guard from.index < waitingQueue.count else { return } }
        if from.queueType == .next { guard from.index < nextQueue.count else { return } }
        
        if to.queueType == .prev { guard to.index <= prevQueue.count else { return } }
        if to.queueType == .waitingQueue { guard to.index <= waitingQueue.count else { return } }
        if to.queueType == .next { guard to.index <= nextQueue.count else { return } }

        // Prev <=> Prev
        if from.queueType == .prev, to.queueType == .prev {
            movePlaylistItem(fromIndex: from.index, to: to.index)
        // Next <=> Next
        } else if from.queueType == .next, to.queueType == .next {
            movePlaylistItem(fromIndex: offsetToNext+from.index, to: offsetToNext+to.index)
        // Waiting <=> Waiting
        } else if from.queueType == .waitingQueue, to.queueType == .waitingQueue {
            moveWaitingQueueItem(fromIndex: from.index + waitingQueueOffsetIsWaitingQueuePlaying, to: to.index + waitingQueueOffsetIsWaitingQueuePlaying)
            
        // Prev ==> Next
        } else if from.queueType == .prev, to.queueType == .next {
            if !isWaitingQueuePlaying {
                movePlaylistItem(fromIndex: from.index, to: offsetToNext+to.index-1)
            } else if from.index == currentIndex, to.index == 0 {
                currentIndex -= 1
            } else {
                movePlaylistItem(fromIndex: from.index, to: offsetToNext+to.index-1)
                currentIndex -= 1
            }
        // Next ==> Prev
        } else if from.queueType == .next, to.queueType == .prev {
            if !isWaitingQueuePlaying {
                movePlaylistItem(fromIndex: offsetToNext+from.index, to: to.index)
            } else if from.index == 0, to.index == currentIndex+1  {
                currentIndex += 1
            } else {
                movePlaylistItem(fromIndex: offsetToNext+from.index, to: to.index)
                currentIndex += 1
            }

        // Waiting ==> Next
        } else if from.queueType == .waitingQueue, to.queueType == .next {
            playerQueues.addToPlaylist(playable: waitingQueue[from.index])
            let fromIndex = playlist.songCount-1
            movePlaylistItem(fromIndex: fromIndex, to: offsetToNext+to.index)
            removeItemFromWaitingQueue(at: from.index + waitingQueueOffsetIsWaitingQueuePlaying)
        // Waiting ==> Prev
        } else if from.queueType == .waitingQueue, to.queueType == .prev {
            playerQueues.addToPlaylist(playable: waitingQueue[from.index])
            let fromIndex = playlist.songCount-1
            movePlaylistItem(fromIndex: fromIndex, to: to.index)
            if isWaitingQueuePlaying {
                currentIndex += 1
            }
            removeItemFromWaitingQueue(at: from.index + waitingQueueOffsetIsWaitingQueuePlaying)

        // Prev ==> Waiting
        } else if from.queueType == .prev, to.queueType == .waitingQueue {
            playerQueues.addToWaitingQueue(playable: prevQueue[from.index])
            moveWaitingQueueItem(fromIndex: waitingQueuePlaylist.songCount-1, to: to.index + waitingQueueOffsetIsWaitingQueuePlaying)
            removeItemFromPlaylist(at: from.index)
        // Next ==> Waiting
        } else if from.queueType == .next, to.queueType == .waitingQueue {
            playerQueues.addToWaitingQueue(playable: nextQueue[from.index])
            moveWaitingQueueItem(fromIndex: waitingQueuePlaylist.songCount-1, to: to.index + waitingQueueOffsetIsWaitingQueuePlaying)
            removeItemFromPlaylist(at: offsetToNext+from.index)
        }
    }
    
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable {
        switch(playerIndex.queueType) {
        case .prev:
            return prevQueue[playerIndex.index]
        case .waitingQueue:
            return waitingQueue[playerIndex.index]
        case .next:
            return nextQueue[playerIndex.index]
        }
    }
    
    private var currentIndex: Int {
        get { return playerQueues.currentIndex }
        set { playerQueues.currentIndex = newValue}
    }
    
    private var playlist: Playlist {
        return playerQueues.activePlaylist
    }
    
    private var waitingQueuePlaylist: Playlist {
        return playerQueues.waitingQueuePlaylist
    }

    private var isWaitingQueueVisible: Bool {
        return playerQueues.isWaitingQueueVisible
    }

    private func removeItemFromWaitingQueue(at index: Int) {
        guard index < waitingQueuePlaylist.playables.count else { return }
        waitingQueuePlaylist.remove(at: index)
    }
    
    private func removeItemFromPlaylist(at index: Int) {
        guard index < playlist.playables.count else { return }
        let playableToRemove = playlist.playables[index]
        if index < currentIndex {
            currentIndex -= 1
        } else if isWaitingQueuePlaying, index == currentIndex {
            currentIndex -= 1
        }
        playlist.remove(at: index)
        playerQueues.inactivePlaylist.remove(firstOccurrenceOfPlayable: playableToRemove)
    }
    
    private func movePlaylistItem(fromIndex: Int, to: Int) {
        guard fromIndex < playlist.playables.count, to < playlist.playables.count, fromIndex != to else { return }
        playlist.movePlaylistItem(fromIndex: fromIndex, to: to)
        guard !isWaitingQueuePlaying else { return }
        if currentIndex == fromIndex {
            currentIndex = to
        } else if fromIndex < currentIndex, currentIndex <= to {
            currentIndex -= 1
        } else if to <= currentIndex, currentIndex < fromIndex {
            currentIndex += 1
        }
    }

    private func moveWaitingQueueItem(fromIndex: Int, to: Int) {
        guard fromIndex < waitingQueuePlaylist.playables.count, to < waitingQueuePlaylist.playables.count, fromIndex != to else { return }
        waitingQueuePlaylist.movePlaylistItem(fromIndex: fromIndex, to: to)
    }

}
