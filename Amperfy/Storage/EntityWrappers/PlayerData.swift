import Foundation
import CoreData

public class PlayerData: NSObject {
    
    private let library: LibraryStorage
    private let managedObject: PlayerMO
    private let normalPlaylist: Playlist
    private let shuffledPlaylist: Playlist
    
    static let entityName: String = { return "Player" }()
    
    init(library: LibraryStorage, managedObject: PlayerMO, normalPlaylist: Playlist, shuffledPlaylist: Playlist) {
        self.library = library
        self.managedObject = managedObject
        self.normalPlaylist = normalPlaylist
        self.shuffledPlaylist = shuffledPlaylist
    }
    
    private var activePlaylist: Playlist {
        get {
            if !isShuffle {
                return normalPlaylist
            } else {
                return shuffledPlaylist
            }
        }
    }
    
    private var inactivePlaylist: Playlist {
        get {
            if !isShuffle {
                return shuffledPlaylist
            } else {
                return normalPlaylist
            }
        }
    }
    
    public var playlist: Playlist {
        get { return activePlaylist }
    }
    public var currentItem: AbstractPlayable? {
        get {
            guard currentIndex < playlist.playables.count else {
                return nil
            }
            return playlist.playables[currentIndex]
        }
    }
    
    public var currentPlaylistItem: PlaylistItem? {
        get {
            guard currentIndex < playlist.playables.count else {
                return nil
            }
            return playlist.items[currentIndex]
        }
    }
    var isAutoCachePlayedItems: Bool {
        get { return managedObject.autoCachePlayedItemSetting == 1 }
        set {
            managedObject.autoCachePlayedItemSetting = newValue ? 1 : 0
            library.saveContext()
        }
    }
    var isShuffle: Bool {
        get {
            return managedObject.shuffleSetting == 1
        }
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
    
    var currentIndex: Int {
        get {
            if managedObject.currentIndex >= playlist.playables.count, managedObject.currentIndex < 0 {
                managedObject.currentIndex = 0
                library.saveContext()
            }
            return Int(managedObject.currentIndex)
        }
        set {
            if newValue >= 0, newValue < playlist.playables.count {
                managedObject.currentIndex = Int32(newValue)
            } else {
                managedObject.currentIndex = 0
            }
            library.saveContext()
        }
    }

    var previousIndex: Int? {
        let prevIndex = currentIndex - 1
        guard prevIndex >= 0 else { return nil }
        if prevIndex >= playlist.playables.count {
            return nil
        } else if playlist.playables.count == 0 {
            return nil
        } else {
            return prevIndex
        }
    }
    
    var nextIndex: Int? {
        let nxtIndex = currentIndex + 1
        if nxtIndex >= playlist.playables.count {
            return nil
        } else {
            return nxtIndex
        }
    }
    
    func addToPlaylist(playable: AbstractPlayable) {
        normalPlaylist.append(playable: playable)
        shuffledPlaylist.append(playable: playable)
    }
    
    func addToPlaylist(playables: [AbstractPlayable]) {
        normalPlaylist.append(playables: playables)
        shuffledPlaylist.append(playables: playables)
    }
    
    func removeAllItems() {
        currentIndex = 0
        normalPlaylist.removeAllItems()
        shuffledPlaylist.removeAllItems()
    }
    
    func removeItemFromPlaylist(at index: Int) {
        if index < playlist.playables.count {
            let playableToRemove = playlist.playables[index]
            activePlaylist.remove(at: index)
            inactivePlaylist.remove(firstOccurrenceOfPlayable: playableToRemove)
            if index < currentIndex {
                currentIndex = currentIndex - 1
            }
        }
    }
    
    func movePlaylistItem(fromIndex: Int, to: Int) {
        if fromIndex < playlist.playables.count, to < playlist.playables.count, fromIndex != to {
            playlist.movePlaylistItem(fromIndex: fromIndex, to: to)
            if currentIndex == fromIndex {
                currentIndex = to
            } else if fromIndex < currentIndex, currentIndex <= to {
                currentIndex = currentIndex - 1
            } else if to <= currentIndex, currentIndex < fromIndex {
                currentIndex = currentIndex + 1
            }
        }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayerData else { return false }
        return managedObject == object.managedObject
    }

}
