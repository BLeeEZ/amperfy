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
        let upcomingItemsCount = min(queueHandler.waitingQueue.count + queueHandler.nextQueue.count, Self.preDownloadCount)
        guard upcomingItemsCount > 0 else { return }
        
        let waitingQueueRangeEnd = min(queueHandler.waitingQueue.count, Self.preDownloadCount)
        if waitingQueueRangeEnd > 0 {
            for i in 0...waitingQueueRangeEnd-1 {
                let playable = queueHandler.waitingQueue[i]
                if !playable.isCached {
                    playableDownloadManager.download(object: playable)
                }
            }
        }
        let nextQueueRangeEnd = min(queueHandler.nextQueue.count, Self.preDownloadCount-waitingQueueRangeEnd)
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
