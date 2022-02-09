import Foundation
import MediaPlayer

protocol MusicPlayable {
    func didStartPlaying()
    func didPause()
    func didStopPlaying()
    func didElapsedTimeChange()
    func didPlaylistChange()
    func didArtworkChange()
    func didShuffleChange()
    func didRepeatChange()
}

extension MusicPlayable {
    func didShuffleChange() { }
    func didRepeatChange() { }
}

enum RepeatMode: Int16 {
    case off
    case all
    case single

    var nextMode: RepeatMode {
        switch self {
        case .off:
            return .all
        case .all:
            return .single
        case .single:
            return .off
        }
    }
    
    var description : String {
        switch self {
        case .off: return "Off"
        case .all: return "All"
        case .single: return "Single"
        }
    }
    
    var asMPRepeatType: MPRepeatType {
        switch self {
        case .off: return .off
        case .all: return .all
        case .single: return .one
        }
    }
    
    static func fromMPRepeatType(type: MPRepeatType) -> RepeatMode {
        switch type {
        case .off:
            return .off
        case .one:
            return .single
        case .all:
            return .all
        default:
            return .off
        }
    }
}

enum PlayerQueueType: Int, CaseIterable {
    case prev = 0
    case user
    case next
    
    var description : String {
        switch self {
        case .prev: return "Previous"
        case .user: return "Next in Queue"
        case .next: return "Next"
        }
    }
}

struct PlayerIndex: Equatable {
    let queueType: PlayerQueueType
    let index: Int
    
    static func create(from indexPath: IndexPath) -> PlayerIndex? {
        guard let queueType = PlayerQueueType(rawValue: indexPath.section) else { return nil }
        return PlayerIndex(queueType: queueType, index: indexPath.row)
    }
}
