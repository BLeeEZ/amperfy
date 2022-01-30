import Foundation

class PlayerDownloadPreparationHandler {
    
    static let preDownloadCount = 3
    
    private var playerStatus: PlayerStatusPersistent
    private var queueHandler: PlayQueueHandler
    private var playableDownloadManager: DownloadManageable

    init(playerStatus: PlayerStatusPersistent, queueHandler: PlayQueueHandler, playableDownloadManager: DownloadManageable) {
        self.playerStatus = playerStatus
        self.queueHandler = queueHandler
        self.playableDownloadManager = playableDownloadManager
    }
    
    private func preDownloadNextItems() {
        let upcomingItemsCount = min(queueHandler.userQueue.count + queueHandler.nextQueue.count, Self.preDownloadCount)
        guard upcomingItemsCount > 0 else { return }
        
        let userQueueRangeEnd = min(queueHandler.userQueue.count, Self.preDownloadCount)
        if userQueueRangeEnd > 0 {
            for i in 0...userQueueRangeEnd-1 {
                let playable = queueHandler.userQueue[i]
                if !playable.isCached {
                    playableDownloadManager.download(object: playable)
                }
            }
        }
        let nextQueueRangeEnd = min(queueHandler.nextQueue.count, Self.preDownloadCount-userQueueRangeEnd)
        if nextQueueRangeEnd > 0 {
            for i in 0...nextQueueRangeEnd-1 {
                let playable = queueHandler.nextQueue[i]
                if !playable.isCached {
                    playableDownloadManager.download(object: playable)
                }
            }
        }
    }

}

extension PlayerDownloadPreparationHandler: MusicPlayable {
    func didStartPlaying() {
        if playerStatus.isAutoCachePlayedItems {
            preDownloadNextItems()
        }
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
