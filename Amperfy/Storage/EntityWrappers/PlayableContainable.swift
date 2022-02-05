import Foundation

enum DetailType {
    case short
    case long
}

protocol PlayableContainable {
    var name: String { get }
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String]
    func info(for api: BackenApiType, type: DetailType) -> String
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
    
    func info(for api: BackenApiType, type: DetailType) -> String {
        return infoDetails(for: api, type: type).joined(separator: " \(CommonString.oneMiddleDot) ")
    }
    
}
