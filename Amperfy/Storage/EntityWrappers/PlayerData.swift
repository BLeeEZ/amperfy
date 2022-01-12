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
    var isWaitingQueuePlaying: Bool { get set }
    var isWaitingQueueVisible: Bool { get }
    
    var currentIndex: Int { get set }
    var currentItem: AbstractPlayable? { get }
    var activePlaylist: Playlist { get }
    var inactivePlaylist: Playlist { get }
    var waitingQueuePlaylist: Playlist { get }
    
    func addToPlaylist(playables: [AbstractPlayable])
    func addToWaitingQueueFirst(playables: [AbstractPlayable])
    func addToWaitingQueueLast(playables: [AbstractPlayable])
    func clearWaitingQueue()
    func clearPlaylistQueues()
    func removeAllItems()
}

public class PlayerData: NSObject {
    
    private let waitingQueuePlaylistInternal: Playlist
    private let library: LibraryStorage
    private let managedObject: PlayerMO
    private let normalPlaylist: Playlist
    private let shuffledPlaylist: Playlist
    
    static let entityName: String = { return "Player" }()
    
    init(library: LibraryStorage, managedObject: PlayerMO, waitingQueuePlaylist: Playlist, normalPlaylist: Playlist, shuffledPlaylist: Playlist) {
        self.library = library
        self.managedObject = managedObject
        self.waitingQueuePlaylistInternal = waitingQueuePlaylist
        self.normalPlaylist = normalPlaylist
        self.shuffledPlaylist = shuffledPlaylist
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayerData else { return false }
        return managedObject == object.managedObject
    }

}

extension PlayerData: PlayerStatusPersistent {
    
    func stop() {
        currentIndex = 0
        isWaitingQueuePlaying = false
        clearWaitingQueue()
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
                shuffledPlaylist.shuffle()
                if let curPlayable = currentItem, let indexOfCurrentItemInShuffledPlaylist = shuffledPlaylist.getFirstIndex(playable: curPlayable) {
                    shuffledPlaylist.movePlaylistItem(fromIndex: indexOfCurrentItemInShuffledPlaylist, to: 0)
                    currentIndex = 0
                }
            } else {
                if let curPlayable = currentItem, let indexOfCurrentItemInNormalPlaylist = normalPlaylist.getFirstIndex(playable: curPlayable) {
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

    var isWaitingQueuePlaying: Bool {
        get { return managedObject.isWaitingQueuePlaying }
        set {
            managedObject.isWaitingQueuePlaying = newValue
            library.saveContext()
        }
    }
    
    var isWaitingQueueVisible: Bool {
        return waitingQueuePlaylistInternal.songCount > 0 && !(isWaitingQueuePlaying && waitingQueuePlaylistInternal.songCount == 1)
    }
    
    var activePlaylist: Playlist {
        get {
            if !isShuffle {
                return normalPlaylist
            } else {
                return shuffledPlaylist
            }
        }
    }
    
    var inactivePlaylist: Playlist {
        get {
            if !isShuffle {
                return shuffledPlaylist
            } else {
                return normalPlaylist
            }
        }
    }
    
    var currentIndex: Int {
        get {
            if managedObject.currentIndex < 0, !isWaitingQueuePlaying {
                managedObject.currentIndex = 0
                library.saveContext()
            }
            if managedObject.currentIndex >= activePlaylist.playables.count || managedObject.currentIndex < -1 {
                managedObject.currentIndex = 0
                library.saveContext()
            }
            return Int(managedObject.currentIndex)
        }
        set {
            if newValue >= -1, newValue < activePlaylist.playables.count {
                managedObject.currentIndex = Int32(newValue)
            } else {
                managedObject.currentIndex = isWaitingQueuePlaying ? -1 : 0
            }
            library.saveContext()
        }
    }
    
    var currentItem: AbstractPlayable? {
        get {
            if isWaitingQueuePlaying, waitingQueuePlaylistInternal.songCount > 0 {
                return waitingQueuePlaylistInternal.playables.first
            }
            guard activePlaylist.playables.count > 0 else { return nil }
            guard currentIndex >= 0, currentIndex < activePlaylist.playables.count else {
                return activePlaylist.playables[0]
            }
            return activePlaylist.playables[currentIndex]
        }
    }

    var waitingQueuePlaylist: Playlist {
        get { return waitingQueuePlaylistInternal }
    }

    func addToPlaylist(playables: [AbstractPlayable]) {
        normalPlaylist.append(playables: playables)
        shuffledPlaylist.append(playables: playables)
    }
    
    func addToWaitingQueueFirst(playables: [AbstractPlayable]) {
        let targetIndex = isWaitingQueuePlaying && waitingQueuePlaylistInternal.songCount > 1 ? 1 : 0
        for playable in playables.reversed() {
            waitingQueuePlaylistInternal.append(playable: playable)
            waitingQueuePlaylistInternal.movePlaylistItem(fromIndex: waitingQueuePlaylistInternal.songCount-1, to: targetIndex)
        }
    }
    
    func addToWaitingQueueLast(playables: [AbstractPlayable]) {
        waitingQueuePlaylistInternal.append(playables: playables)
    }
    
    func clearPlaylistQueues() {
        normalPlaylist.removeAllItems()
        shuffledPlaylist.removeAllItems()
        if waitingQueuePlaylistInternal.songCount > 0 {
            isWaitingQueuePlaying = true
            currentIndex = -1
        } else {
            currentIndex = 0
        }
    }
    
    func clearWaitingQueue() {
        waitingQueuePlaylistInternal.removeAllItems()
    }
    
    func removeAllItems() {
        currentIndex = 0
        isWaitingQueuePlaying = false
        normalPlaylist.removeAllItems()
        shuffledPlaylist.removeAllItems()
        waitingQueuePlaylistInternal.removeAllItems()
    }
}
    
