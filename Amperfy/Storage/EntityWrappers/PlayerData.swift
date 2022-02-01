import Foundation
import CoreData
import CoreMedia
import UIKit

protocol PlayerStatusPersistent {
    func stop()
    var isAutoCachePlayedItems: Bool { get set }
    var isShuffle: Bool { get set }
    var repeatMode: RepeatMode { get set }
}

protocol PlayerQueuesPersistent {
    var isUserQueuePlaying: Bool { get set }
    var isUserQueueVisible: Bool { get }
    
    var currentIndex: Int { get set }
    var currentItem: AbstractPlayable? { get }
    var contextQueue: Playlist { get }
    var contextName: String { get set }
    var inactiveContextQueue: Playlist { get }
    var userQueuePlaylist: Playlist { get }
    
    func insertContextQueue(playables: [AbstractPlayable])
    func appendContextQueue(playables: [AbstractPlayable])
    func insertUserQueue(playables: [AbstractPlayable])
    func appendUserQueue(playables: [AbstractPlayable])
    func clearUserQueue()
    func clearContextQueue()
    func removeAllItems()
}

public class PlayerData: NSObject {
    
    private let userQueuePlaylistInternal: Playlist
    private let library: LibraryStorage
    private let managedObject: PlayerMO
    private let contextPlaylist: Playlist
    private let shuffledContextPlaylist: Playlist
    
    static let entityName: String = { return "Player" }()
    
    init(library: LibraryStorage, managedObject: PlayerMO, userQueue: Playlist, contextQueue: Playlist, shuffledContextQueue: Playlist) {
        self.library = library
        self.managedObject = managedObject
        self.userQueuePlaylistInternal = userQueue
        self.contextPlaylist = contextQueue
        self.shuffledContextPlaylist = shuffledContextQueue
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayerData else { return false }
        return managedObject == object.managedObject
    }

}

extension PlayerData: PlayerStatusPersistent {
    
    func stop() {
        currentIndex = 0
        isUserQueuePlaying = false
        clearUserQueue()
    }
    
    var isAutoCachePlayedItems: Bool {
        get { return managedObject.autoCachePlayedItemSetting == 1 }
        set {
            managedObject.autoCachePlayedItemSetting = newValue ? 1 : 0
            library.saveContext()
        }
    }
    
    var isShuffle: Bool {
        get { return managedObject.shuffleSetting == 1 }
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
            return RepeatMode(rawValue: managedObject.repeatSetting) ?? .off
        }
        set {
            managedObject.repeatSetting = newValue.rawValue
            library.saveContext()
        }
    }

}

extension PlayerData: PlayerQueuesPersistent {
    var isUserQueuePlaying: Bool {
        get { return managedObject.isUserQueuePlaying }
        set {
            managedObject.isUserQueuePlaying = newValue
            library.saveContext()
        }
    }
    
    var isUserQueueVisible: Bool {
        return userQueuePlaylistInternal.songCount > 0 && !(isUserQueuePlaying && userQueuePlaylistInternal.songCount == 1)
    }
    
    var contextQueue: Playlist {
        get {
            if !isShuffle {
                return contextPlaylist
            } else {
                return shuffledContextPlaylist
            }
        }
    }
    
    var inactiveContextQueue: Playlist {
        get {
            if !isShuffle {
                return shuffledContextPlaylist
            } else {
                return contextPlaylist
            }
        }
    }
    
    var contextName: String {
        get { contextPlaylist.name }
        set { contextPlaylist.name = newValue }
    }
    
    var currentIndex: Int {
        get {
            if managedObject.currentIndex < 0, !isUserQueuePlaying {
                managedObject.currentIndex = 0
                library.saveContext()
            }
            if managedObject.currentIndex >= contextQueue.playables.count || managedObject.currentIndex < -1 {
                managedObject.currentIndex = 0
                library.saveContext()
            }
            return Int(managedObject.currentIndex)
        }
        set {
            if newValue >= -1, newValue < contextQueue.playables.count {
                managedObject.currentIndex = Int32(newValue)
            } else {
                managedObject.currentIndex = isUserQueuePlaying ? -1 : 0
            }
            library.saveContext()
        }
    }
    
    var currentItem: AbstractPlayable? {
        get {
            if isUserQueuePlaying, userQueuePlaylistInternal.songCount > 0 {
                return userQueuePlaylistInternal.playables.first
            }
            guard contextQueue.playables.count > 0 else { return nil }
            guard currentIndex >= 0, currentIndex < contextQueue.playables.count else {
                return contextQueue.playables[0]
            }
            return contextQueue.playables[currentIndex]
        }
    }

    var userQueuePlaylist: Playlist {
        get { return userQueuePlaylistInternal }
    }

    func insertContextQueue(playables: [AbstractPlayable]) {
        var targetIndex = currentIndex+1
        if contextPlaylist.songCount == 0 {
            if isUserQueuePlaying {
                currentIndex = -1
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
        let targetIndex = isUserQueuePlaying && userQueuePlaylistInternal.songCount > 0 ? 1 : 0
        userQueuePlaylistInternal.insert(playables: playables, index: targetIndex)
    }
    
    func appendUserQueue(playables: [AbstractPlayable]) {
        userQueuePlaylistInternal.append(playables: playables)
    }
    
    func clearContextQueue() {
        contextPlaylist.removeAllItems()
        shuffledContextPlaylist.removeAllItems()
        if userQueuePlaylistInternal.songCount > 0 {
            isUserQueuePlaying = true
            currentIndex = -1
        } else {
            currentIndex = 0
        }
    }
    
    func clearUserQueue() {
        userQueuePlaylistInternal.removeAllItems()
    }
    
    func removeAllItems() {
        currentIndex = 0
        isUserQueuePlaying = false
        contextPlaylist.removeAllItems()
        shuffledContextPlaylist.removeAllItems()
        userQueuePlaylistInternal.removeAllItems()
    }
}
    
