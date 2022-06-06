import Foundation
import CoreData
import CoreMedia
import UIKit

protocol PlayerStatusPersistent {
    func stop()
    var isAutoCachePlayedItems: Bool { get set }
    var isPopupBarAllowedToHide: Bool { get }
    var playerMode: PlayerMode { get set }
    var isShuffle: Bool { get set }
    var repeatMode: RepeatMode { get set }
}

protocol PlayerQueuesPersistent {
    var isUserQueuePlaying: Bool { get set }
    var isUserQueueVisible: Bool { get }

    var currentIndex: Int { get set }
    var currentItem: AbstractPlayable? { get }
    var activeQueue: Playlist { get }
    var inactiveQueue: Playlist { get }
    var contextQueue: Playlist { get }
    var podcastQueue: Playlist { get }
    var contextName: String { get set }
    var userQueuePlaylist: Playlist { get }
    
    func insertActiveQueue(playables: [AbstractPlayable])
    func appendActiveQueue(playables: [AbstractPlayable])
    func insertContextQueue(playables: [AbstractPlayable])
    func appendContextQueue(playables: [AbstractPlayable])
    func insertUserQueue(playables: [AbstractPlayable])
    func appendUserQueue(playables: [AbstractPlayable])
    func insertPodcastQueue(playables: [AbstractPlayable])
    func appendPodcastQueue(playables: [AbstractPlayable])
    func clearActiveQueue()
    func clearUserQueue()
    func clearContextQueue()
    func removeAllItems()
}

public enum PlayerMode: Int16 {
    case music = 0
    case podcast = 1
}

public class PlayerData: NSObject {
    
    private let userQueuePlaylistInternal: Playlist
    private let library: LibraryStorage
    private let managedObject: PlayerMO
    private let contextPlaylist: Playlist
    private let shuffledContextPlaylist: Playlist
    private let podcastPlaylist: Playlist
    
    static let entityName: String = { return "Player" }()
    
    init(library: LibraryStorage, managedObject: PlayerMO, userQueue: Playlist, contextQueue: Playlist, shuffledContextQueue: Playlist, podcastQueue: Playlist) {
        self.library = library
        self.managedObject = managedObject
        self.userQueuePlaylistInternal = userQueue
        self.contextPlaylist = contextQueue
        self.shuffledContextPlaylist = shuffledContextQueue
        self.podcastPlaylist = podcastQueue
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayerData else { return false }
        return managedObject == object.managedObject
    }

}

extension PlayerData: PlayerStatusPersistent {
    
    func stop() {
        currentIndex = 0
        switch playerMode {
        case .music:
            isUserQueuePlaying = false
            clearUserQueue()
        case .podcast:
            break
        }
    }
    
    var isAutoCachePlayedItems: Bool {
        get { return managedObject.autoCachePlayedItemSetting == 1 }
        set {
            managedObject.autoCachePlayedItemSetting = newValue ? 1 : 0
            library.saveContext()
        }
    }
    
    var isPopupBarAllowedToHide: Bool {
        return podcastPlaylist.songCount == 0 && contextPlaylist.songCount == 0 && userQueuePlaylistInternal.songCount == 0
    }
    
    
    var playerMode: PlayerMode {
        get { return PlayerMode(rawValue: managedObject.playerMode) ?? .music }
        set {
            managedObject.playerMode = newValue.rawValue
            library.saveContext()
        }
    }
    
    var isShuffle: Bool {
        get {
            switch playerMode {
            case .music:
                return managedObject.shuffleSetting == 1
            case .podcast:
                return false
            }
        }
        set {
            if newValue {
                shuffledContextPlaylist.shuffle()
                if let curPlayable = currentItem, let indexOfCurrentItemInShuffledPlaylist = shuffledContextPlaylist.getFirstIndex(playable: curPlayable) {
                    shuffledContextPlaylist.movePlaylistItem(fromIndex: indexOfCurrentItemInShuffledPlaylist, to: 0)
                    currentIndex = 0
                }
            } else {
                if let curPlayable = currentItem, let indexOfCurrentItemInNormalPlaylist = contextPlaylist.getFirstIndex(playable: curPlayable) {
                    currentIndex = indexOfCurrentItemInNormalPlaylist
                }
            }
            managedObject.shuffleSetting = newValue ? 1 : 0
            library.saveContext()
        }
    }
    
    var repeatMode: RepeatMode {
        get {
            switch playerMode {
            case .music:
                return RepeatMode(rawValue: managedObject.repeatSetting) ?? .off
            case .podcast:
                return .off
            }
        }
        set {
            managedObject.repeatSetting = newValue.rawValue
            library.saveContext()
        }
    }

}

extension PlayerData: PlayerQueuesPersistent {
    var isUserQueuePlaying: Bool {
        get {
            switch playerMode {
            case .music:
                return isUserQueuPlayingInternal
            case .podcast:
                return false
            }
        }
        set {
            switch playerMode {
            case .music:
                isUserQueuPlayingInternal = newValue
            case .podcast:
                break
            }
        }
    }
    
    private var isUserQueuPlayingInternal: Bool {
        get { return managedObject.isUserQueuePlaying }
        set {
            managedObject.isUserQueuePlaying = newValue
            library.saveContext()
        }
    }
    
    var isUserQueueVisible: Bool {
        switch playerMode {
        case .music:
            return userQueuePlaylistInternal.songCount > 0 && !(isUserQueuPlayingInternal && userQueuePlaylistInternal.songCount == 1)
        case .podcast:
            return false
        }
    }
    
    var activeQueue: Playlist {
        get {
            switch playerMode {
            case .music:
                if !isShuffle {
                    return contextPlaylist
                } else {
                    return shuffledContextPlaylist
                }
            case .podcast:
                return podcastPlaylist
            }
        }
    }
    
    var inactiveQueue: Playlist {
        get {
            switch playerMode {
            case .music:
                if !isShuffle {
                    return shuffledContextPlaylist
                } else {
                    return contextPlaylist
                }
            case .podcast:
                return podcastPlaylist
            }
        }
    }
    var contextQueue: Playlist { return contextPlaylist }
    var podcastQueue: Playlist { return podcastPlaylist }
    
    var contextName: String {
        get {
            switch playerMode {
            case .music:
                return contextPlaylist.name
            case .podcast:
                return "Podcasts"
            }
        }
        set {
            contextPlaylist.name = newValue
        }
    }
    
    var currentIndex: Int {
        get {
            switch playerMode {
            case .music:
                return currentMusicIndex
            case .podcast:
                return currentPodcastIndex
            }
        }
        set {
            switch playerMode {
            case .music:
                currentMusicIndex = newValue
            case .podcast:
                currentPodcastIndex = newValue
            }
        }
    }
    
    private var currentMusicIndex: Int {
        get {
            if managedObject.musicIndex < 0, !isUserQueuPlayingInternal {
                return 0
            }
            if managedObject.musicIndex >= contextQueue.playables.count || managedObject.musicIndex < -1 {
                return 0
            }
            return Int(managedObject.musicIndex)
        }
        set {
            if newValue >= -1, newValue < contextQueue.playables.count {
                managedObject.musicIndex = Int32(newValue)
            } else {
                managedObject.musicIndex = isUserQueuPlayingInternal ? -1 : 0
            }
            library.saveContext()
        }
    }
    
    private var currentPodcastIndex: Int {
        get {
            if managedObject.podcastIndex < 0 || (managedObject.podcastIndex >= podcastPlaylist.playables.count && podcastPlaylist.playables.count > 0)  {
                return 0
            }
            return Int(managedObject.podcastIndex)
        }
        set {
            if newValue >= 0, newValue < podcastPlaylist.playables.count {
                managedObject.podcastIndex = Int32(newValue)
            } else {
                managedObject.podcastIndex = 0
            }
            library.saveContext()
        }
    }
    
    var currentItem: AbstractPlayable? {
        get {
            switch playerMode {
            case .music:
                if isUserQueuPlayingInternal, userQueuePlaylistInternal.songCount > 0 {
                    return userQueuePlaylistInternal.playables.first
                }
                guard activeQueue.playables.count > 0 else { return nil }
                guard currentMusicIndex >= 0, currentMusicIndex < activeQueue.playables.count else {
                    return activeQueue.playables[0]
                }
                return activeQueue.playables[currentMusicIndex]
            case .podcast:
                return podcastPlaylist.playables.element(at: currentPodcastIndex)
            }
        }
    }

    var userQueuePlaylist: Playlist {
        get { return userQueuePlaylistInternal }
    }
    
    func insertActiveQueue(playables: [AbstractPlayable]) {
        switch playerMode {
        case .music:
            insertContextQueue(playables: playables)
        case .podcast:
            insertPodcastQueue(playables: playables)
        }
    }

    func appendActiveQueue(playables: [AbstractPlayable]) {
        switch playerMode {
        case .music:
            appendContextQueue(playables: playables)
        case .podcast:
            appendPodcastQueue(playables: playables)
        }
    }

    func insertContextQueue(playables: [AbstractPlayable]) {
        var targetIndex = currentMusicIndex+1
        if contextPlaylist.songCount == 0 {
            if isUserQueuPlayingInternal {
                currentMusicIndex = -1
            }
            targetIndex = 0
        }
        contextPlaylist.insert(playables: playables, index: targetIndex)
        shuffledContextPlaylist.insert(playables: playables, index: targetIndex)
    }
    
    func appendContextQueue(playables: [AbstractPlayable]) {
        contextPlaylist.append(playables: playables)
        shuffledContextPlaylist.append(playables: playables)
    }
    
    func insertUserQueue(playables: [AbstractPlayable]) {
        let targetIndex = isUserQueuPlayingInternal && userQueuePlaylistInternal.songCount > 0 ? 1 : 0
        userQueuePlaylistInternal.insert(playables: playables, index: targetIndex)
    }
    
    func appendUserQueue(playables: [AbstractPlayable]) {
        userQueuePlaylistInternal.append(playables: playables)
    }
    
    func insertPodcastQueue(playables: [AbstractPlayable]) {
        var targetIndex = currentPodcastIndex+1
        if podcastPlaylist.songCount == 0 {
            targetIndex = 0
        }
        podcastPlaylist.insert(playables: playables, index: targetIndex)
    }
    
    func appendPodcastQueue(playables: [AbstractPlayable]) {
        podcastPlaylist.append(playables: playables)
    }
    
    func clearActiveQueue() {
        switch playerMode {
        case .music:
            clearContextQueue()
        case .podcast:
            podcastPlaylist.removeAllItems()
            currentIndex = 0
        }

    }
    
    func clearContextQueue() {
        contextName = ""
        contextPlaylist.removeAllItems()
        shuffledContextPlaylist.removeAllItems()
        if userQueuePlaylistInternal.songCount > 0 {
            isUserQueuPlayingInternal = true
            currentMusicIndex = -1
        } else {
            currentMusicIndex = 0
        }
    }
    
    func clearUserQueue() {
        userQueuePlaylistInternal.removeAllItems()
    }
    
    func removeAllItems() {
        currentIndex = 0
        isUserQueuPlayingInternal = false
        contextPlaylist.removeAllItems()
        shuffledContextPlaylist.removeAllItems()
        userQueuePlaylistInternal.removeAllItems()
        podcastPlaylist.removeAllItems()
    }
}
    
