import Foundation

protocol PlayableContainable {
    var playables: [AbstractPlayable] { get }
    var duration: Int { get }
    var hasCachedPlayables: Bool { get }
    func cachePlayables(downloadManager: DownloadManageable)
}

extension PlayableContainable {
    var duration: Int {
        return playables.reduce(0){ $0 + $1.duration }
    }
    
    var hasCachedPlayables: Bool {
        return playables.hasCachedItems
    }
    
    func cachePlayables(downloadManager: DownloadManageable) {
        for playable in playables {
            if !playable.isCached {
                downloadManager.download(object: playable)
            }
        }
    }
    
}
