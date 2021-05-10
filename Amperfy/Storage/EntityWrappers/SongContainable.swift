import Foundation

protocol SongContainable {
    var songs: [Song] { get }
    var duration: Int { get }
}

extension SongContainable {
    var duration: Int {
        return songs.reduce(0){ $0 + $1.duration }
    }
}
