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
        if isUserQueuePlaying, currentIndex == -1 {
            // prev is empty
        } else if isUserQueuePlaying, currentIndex == 0, contextQueue.songCount > 0 {
            played = [contextQueue.playables[0]]
        } else if currentIndex > 0 {
            if isUserQueuePlaying {
                played = Array(contextQueue.playables[0...currentIndex])
            } else {
                played = Array(contextQueue.playables[0...currentIndex-1])
            }
        }
        return played
    }
    
    var userQueue: [AbstractPlayable] {
        var userQueue = [AbstractPlayable]()
        if isUserQueueVisible {
            if isUserQueuePlaying {
                userQueue = Array(userQueuePlaylist.playables[1...])
            } else {
                userQueue = userQueuePlaylist.playables
            }
        }
        return userQueue
    }
    
    var nextQueue: [AbstractPlayable] {
        if contextQueue.playables.count > 0, currentIndex < contextQueue.playables.count-1 {
            return Array(contextQueue.playables[(currentIndex+1)...])
        } else {
            return [AbstractPlayable]()
        }
    }
    
    var contextName: String {
        get { playerQueues.contextName }
        set { playerQueues.contextName = newValue }
    }

    var isUserQueuePlaying: Bool {
        return playerQueues.isUserQueuePlaying
    }

    func insertContextQueue(playables: [AbstractPlayable]) {
        playerQueues.contextName = ""
        playerQueues.insertContextQueue(playables: playables)
    }
    
    func appendContextQueue(playables: [AbstractPlayable]) {
        playerQueues.contextName = ""
        playerQueues.appendContextQueue(playables: playables)
    }
    
    func insertUserQueue(playables: [AbstractPlayable]) {
        playerQueues.insertUserQueue(playables: playables)
        if playerQueues.contextQueue.songCount == 0 {
            playerQueues.isUserQueuePlaying = true
        }
    }
    
    func appendUserQueue(playables: [AbstractPlayable]) {
        playerQueues.appendUserQueue(playables: playables)
        if playerQueues.contextQueue.songCount == 0 {
            playerQueues.isUserQueuePlaying = true
        }
    }
    
    func clearContextQueue() {
        playerQueues.contextName = ""
        playerQueues.clearContextQueue()
    }
    
    func clearUserQueue() {
        if isUserQueuePlaying, let currentUserQueueItem = currentlyPlaying {
            playerQueues.clearUserQueue()
            insertUserQueue(playables: [currentUserQueueItem])
        } else {
            playerQueues.clearUserQueue()
        }
    }
    
    func removeAllItems() {
        playerQueues.contextName = ""
        playerQueues.removeAllItems()
    }

    func markAndGetPlayableAsPlaying(at playerIndex: PlayerIndex) -> AbstractPlayable? {
        var playable: AbstractPlayable?
        if playerIndex.queueType == .user, playerIndex.index >= 0, playerIndex.index < userQueue.count {
            playable = userQueue[playerIndex.index]
            if isUserQueuePlaying {
                removeItemFromUserQueue(at: 0)
            }
            if playerIndex.index > 0 {
                for _ in 1...playerIndex.index {
                    removeItemFromUserQueue(at: 0)
                }
            }
            playerQueues.isUserQueuePlaying = true
        } else if playerIndex.queueType == .prev, playerIndex.index >= 0, playerIndex.index < prevQueue.count {
            if isUserQueuePlaying {
                removeItemFromUserQueue(at: 0)
            }
            playable = prevQueue[playerIndex.index]
            currentIndex = playerIndex.index
            playerQueues.isUserQueuePlaying = false
        } else if playerIndex.queueType == .next, playerIndex.index >= 0, playerIndex.index < nextQueue.count {
            if isUserQueuePlaying {
                removeItemFromUserQueue(at: 0)
            }
            playable = nextQueue[playerIndex.index]
            if isUserQueuePlaying {
                currentIndex = prevQueue.count + playerIndex.index
            } else {
                currentIndex = prevQueue.count + 1 + playerIndex.index
            }
            playerQueues.isUserQueuePlaying = false
        }
        return playable
    }
    
    func removePlayable(at: PlayerIndex) {
        switch(at.queueType) {
        case .user:
            if isUserQueuePlaying {
                removeItemFromUserQueue(at: at.index+1)
            } else {
                removeItemFromUserQueue(at: at.index)
            }
        case .prev:
            removeItemFromContext(at: at.index)
        case .next:
            var playlistIndex = prevQueue.count + at.index
            if !isUserQueuePlaying {
                playlistIndex += 1
            }
            removeItemFromContext(at: playlistIndex)
        }
    }
    
    func movePlayable(from: PlayerIndex, to: PlayerIndex) {
        let userQueueOffsetIsUserQueuePlaying = isUserQueuePlaying ? 1 : 0
        let nextQueueOffsetIsUserQueuePlaying = isUserQueuePlaying ? 0 : 1
        let offsetToNext = prevQueue.count + nextQueueOffsetIsUserQueuePlaying
        
        guard from.index >= 0, to.index >= 0 else { return }
        
        if from.queueType == .prev { guard from.index < prevQueue.count else { return } }
        if from.queueType == .user { guard from.index < userQueue.count else { return } }
        if from.queueType == .next { guard from.index < nextQueue.count else { return } }
        
        if to.queueType == .prev { guard to.index <= prevQueue.count else { return } }
        if to.queueType == .user { guard to.index <= userQueue.count else { return } }
        if to.queueType == .next { guard to.index <= nextQueue.count else { return } }

        // Prev <=> Prev
        if from.queueType == .prev, to.queueType == .prev {
            moveContextItem(fromIndex: from.index, to: to.index)
        // Next <=> Next
        } else if from.queueType == .next, to.queueType == .next {
            moveContextItem(fromIndex: offsetToNext+from.index, to: offsetToNext+to.index)
        // User <=> User
        } else if from.queueType == .user, to.queueType == .user {
            moveUserQueueItem(fromIndex: from.index + userQueueOffsetIsUserQueuePlaying, to: to.index + userQueueOffsetIsUserQueuePlaying)
            
        // Prev ==> Next
        } else if from.queueType == .prev, to.queueType == .next {
            if !isUserQueuePlaying {
                moveContextItem(fromIndex: from.index, to: offsetToNext+to.index-1)
            } else if from.index == currentIndex, to.index == 0 {
                currentIndex -= 1
            } else {
                moveContextItem(fromIndex: from.index, to: offsetToNext+to.index-1)
                currentIndex -= 1
            }
        // Next ==> Prev
        } else if from.queueType == .next, to.queueType == .prev {
            if !isUserQueuePlaying {
                moveContextItem(fromIndex: offsetToNext+from.index, to: to.index)
            } else if from.index == 0, to.index == currentIndex+1  {
                currentIndex += 1
            } else {
                moveContextItem(fromIndex: offsetToNext+from.index, to: to.index)
                currentIndex += 1
            }

        // User ==> Next
        } else if from.queueType == .user, to.queueType == .next {
            playerQueues.appendContextQueue(playables: [userQueue[from.index]])
            let fromIndex = contextQueue.songCount-1
            moveContextItem(fromIndex: fromIndex, to: offsetToNext+to.index)
            removeItemFromUserQueue(at: from.index + userQueueOffsetIsUserQueuePlaying)
        // User ==> Prev
        } else if from.queueType == .user, to.queueType == .prev {
            playerQueues.appendContextQueue(playables: [userQueue[from.index]])
            let fromIndex = contextQueue.songCount-1
            moveContextItem(fromIndex: fromIndex, to: to.index)
            if isUserQueuePlaying {
                currentIndex += 1
            }
            removeItemFromUserQueue(at: from.index + userQueueOffsetIsUserQueuePlaying)

        // Prev ==> User
        } else if from.queueType == .prev, to.queueType == .user {
            playerQueues.appendUserQueue(playables: [prevQueue[from.index]])
            moveUserQueueItem(fromIndex: userQueuePlaylist.songCount-1, to: to.index + userQueueOffsetIsUserQueuePlaying)
            removeItemFromContext(at: from.index)
        // Next ==> User
        } else if from.queueType == .next, to.queueType == .user {
            playerQueues.appendUserQueue(playables: [nextQueue[from.index]])
            moveUserQueueItem(fromIndex: userQueuePlaylist.songCount-1, to: to.index + userQueueOffsetIsUserQueuePlaying)
            removeItemFromContext(at: offsetToNext+from.index)
        }
    }
    
    func getPlayable(at playerIndex: PlayerIndex) -> AbstractPlayable {
        switch(playerIndex.queueType) {
        case .prev:
            return prevQueue[playerIndex.index]
        case .user:
            return userQueue[playerIndex.index]
        case .next:
            return nextQueue[playerIndex.index]
        }
    }
    
    private var currentIndex: Int {
        get { return playerQueues.currentIndex }
        set { playerQueues.currentIndex = newValue}
    }
    
    private var contextQueue: Playlist {
        return playerQueues.contextQueue
    }

    private var userQueuePlaylist: Playlist {
        return playerQueues.userQueuePlaylist
    }

    private var isUserQueueVisible: Bool {
        return playerQueues.isUserQueueVisible
    }

    private func removeItemFromUserQueue(at index: Int) {
        guard index < userQueuePlaylist.playables.count else { return }
        userQueuePlaylist.remove(at: index)
    }
    
    private func removeItemFromContext(at index: Int) {
        guard index < contextQueue.playables.count else { return }
        let playableToRemove = contextQueue.playables[index]
        if index < currentIndex {
            currentIndex -= 1
        } else if isUserQueuePlaying, index == currentIndex {
            currentIndex -= 1
        }
        contextQueue.remove(at: index)
        playerQueues.inactiveContextQueue.remove(firstOccurrenceOfPlayable: playableToRemove)
    }
    
    private func moveContextItem(fromIndex: Int, to: Int) {
        guard fromIndex < contextQueue.playables.count, to < contextQueue.playables.count, fromIndex != to else { return }
        contextQueue.movePlaylistItem(fromIndex: fromIndex, to: to)
        guard !isUserQueuePlaying else { return }
        if currentIndex == fromIndex {
            currentIndex = to
        } else if fromIndex < currentIndex, currentIndex <= to {
            currentIndex -= 1
        } else if to <= currentIndex, currentIndex < fromIndex {
            currentIndex += 1
        }
    }

    private func moveUserQueueItem(fromIndex: Int, to: Int) {
        guard fromIndex < userQueuePlaylist.playables.count, to < userQueuePlaylist.playables.count, fromIndex != to else { return }
        userQueuePlaylist.movePlaylistItem(fromIndex: fromIndex, to: to)
    }

}
