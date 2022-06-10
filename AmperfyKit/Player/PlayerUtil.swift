import Foundation
import MediaPlayer

public protocol MusicPlayable {
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

public enum RepeatMode: Int16 {
    case off
    case all
    case single

    public var nextMode: RepeatMode {
        switch self {
        case .off:
            return .all
        case .all:
            return .single
        case .single:
            return .off
        }
    }
    
    public var description : String {
        switch self {
        case .off: return "Off"
        case .all: return "All"
        case .single: return "Single"
        }
    }
    
    public  var asMPRepeatType: MPRepeatType {
        switch self {
        case .off: return .off
        case .all: return .all
        case .single: return .one
        }
    }
    
    public static func fromMPRepeatType(type: MPRepeatType) -> RepeatMode {
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
    
    public static func fromIntent(type: RepeatType) -> RepeatMode {
        switch type {
        case .unknown:
            return .off
        case .single:
            return .single
        case .all:
            return .all
        case .off:
            return .off
        }
    }
}

public enum PlayerQueueType: Int, CaseIterable {
    case prev = 0
    case user
    case next
    
    public var description : String {
        switch self {
        case .prev: return "Previous"
        case .user: return "Next in Queue"
        case .next: return "Next"
        }
    }
}

public struct PlayerIndex: Equatable {
    let queueType: PlayerQueueType
    let index: Int
    
    public static func create(from indexPath: IndexPath) -> PlayerIndex? {
        guard let queueType = PlayerQueueType(rawValue: indexPath.section) else { return nil }
        return PlayerIndex(queueType: queueType, index: indexPath.row)
    }
}
