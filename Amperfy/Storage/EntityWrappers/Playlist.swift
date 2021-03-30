import Foundation
import CoreData
import os.log

public class Playlist: NSObject {
    
    let managedObject: PlaylistMO
    private let storage: LibraryStorage
    
    init(storage: LibraryStorage, managedObject: PlaylistMO) {
        self.storage = storage
        self.managedObject = managedObject
    }
    
    private var sortedPlaylistItems: [PlaylistItem] {
        var sortedItems = [PlaylistItem]()
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else {
            return sortedItems
        }
        sortedItems = itemsMO.lazy
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(storage: storage, managedObject: $0) }
        return sortedItems
    }
    
    private var sortedCachedPlaylistItems: [PlaylistItem] {
        var sortedCachedItems = [PlaylistItem]()
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else {
            return sortedCachedItems
        }
        sortedCachedItems = itemsMO.lazy
            .filter{ return $0.song?.file != nil }
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(storage: storage, managedObject: $0) }
        return sortedCachedItems
    }
    
    var songs: [Song] {
        var songArray = [Song]()
        for playlistItem in sortedPlaylistItems {
            if let song = playlistItem.song {
                songArray.append(song)
            }
        }
        return songArray
    }
    var items: [PlaylistItem] {
        return sortedPlaylistItems
    }
    var id: String {
        get {
            return managedObject.id
        }
        set {
            managedObject.id = newValue
            storage.saveContext()
        }
    }
    var name: String {
        get {
            return managedObject.name ?? ""
        }
        set {
            managedObject.name = newValue
            storage.saveContext()
        }
    }
    var isSmartPlaylist: Bool {
        return id.hasPrefix("smart_")
    }
    var lastSongIndex: Int {
        guard songs.count > 0 else { return 0 }
        return songs.count-1
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    var info: String {
        var infoText = "Name: " + name + "\n"
        infoText += "Count: " + String(sortedPlaylistItems.count) + "\n"
        infoText += "Songs:\n"
        for playlistItem in sortedPlaylistItems {
            infoText += String(playlistItem.order) + ": "
            if let song = playlistItem.song {
                infoText += song.artist?.name ?? "NO ARTIST"
                infoText += " - "
                infoText += song.title
            } else {
                infoText += "NOT AVAILABLE"
            }
            infoText += "\n"
        }
        return infoText
    }
    
    func previousCachedSongIndex(downwardsFrom: Int) -> Int? {
        let cachedPlaylistItems = sortedCachedPlaylistItems
        guard downwardsFrom <= songs.count, !cachedPlaylistItems.isEmpty else {
            return nil
        }
        var previousIndex: Int? = nil
        for item in cachedPlaylistItems.reversed() {
            if item.order < downwardsFrom {
                previousIndex = Int(item.order)
                break
            }
        }
        return previousIndex
    }
    
    func previousCachedSongIndex(beginningAt: Int) -> Int? {
        return previousCachedSongIndex(downwardsFrom: beginningAt+1)
    }
    
    func nextCachedSongIndex(upwardsFrom: Int) -> Int? {
        let cachedPlaylistItems = sortedCachedPlaylistItems
        guard upwardsFrom < songs.count, !cachedPlaylistItems.isEmpty else {
            return nil
        }
        var nextIndex: Int? = nil
        for item in cachedPlaylistItems {
            if item.order > upwardsFrom {
                nextIndex = Int(item.order)
                break
            }
        }
        return nextIndex
    }
    
    func nextCachedSongIndex(beginningAt: Int) -> Int? {
        return nextCachedSongIndex(upwardsFrom: beginningAt-1)
    }
    
    func append(song: Song) {
        createPlaylistItem(forSong: song)
        storage.saveContext()
    }

    func append(songs songsToAppend: [Song]) {
        for song in songsToAppend {
            createPlaylistItem(forSong: song)
        }
        storage.saveContext()
    }
    
    private func createPlaylistItem(forSong song: Song) {
        let playlistItem = storage.createPlaylistItem()
        playlistItem.order = managedObject.items!.count
        playlistItem.playlist = self
        playlistItem.song = song
    }

    func add(item: PlaylistItem) {
        managedObject.addToItems(item.managedObject)
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        guard fromIndex >= 0, fromIndex < songs.count, to >= 0, to < songs.count, fromIndex != to else { return }
        
        let localSortedPlaylistItems = sortedPlaylistItems
        let targetOrder = localSortedPlaylistItems[to].order
        if fromIndex < to {
            for i in fromIndex+1...to {
                localSortedPlaylistItems[i].order = localSortedPlaylistItems[i].order - 1
            }
        } else {
            for i in to...fromIndex-1 {
                localSortedPlaylistItems[i].order = localSortedPlaylistItems[i].order + 1
            }
        }
        localSortedPlaylistItems[fromIndex].order = targetOrder
        
        storage.saveContext()
    }
    
    func remove(at index: Int) {
        if index < sortedPlaylistItems.count {
            let itemToBeRemoved = sortedPlaylistItems[index]
            for item in sortedPlaylistItems {
                if item.order > index {
                    item.order = item.order - 1
                }
            }
            storage.deletePlaylistItem(item: itemToBeRemoved)
            storage.saveContext()
        }
    }
    
    func remove(firstOccurrenceOfSong song: Song) {
        for item in items {
            if item.song?.id == song.id {
                remove(at: Int(item.order))
                break
            }
        }
    }
    
    func getFirstIndex(song: Song) -> Int? {
        for item in items {
            if item.song?.id == song.id {
                return Int(item.order)
            }
        }
        return nil
    }
    
    func removeAllSongs() {
        for item in sortedPlaylistItems {
            storage.deletePlaylistItem(item: item)
        }
        storage.saveContext()
    }
    
    func shuffle() {
        if songs.count > 0 {
            for i in 0..<songs.count {
                movePlaylistSong(fromIndex: i, to: Int.random(in: 0..<songs.count))
            }
        }
    }

    func ensureConsistentItemOrder() {
        var hasInconsistencyDetected = false
        for (index, item) in sortedPlaylistItems.enumerated() {
            if item.order != index {
                item.order = index
                hasInconsistencyDetected = true
            }
        }
        if hasInconsistencyDetected {
            os_log(.debug, "Playlist inconsistency detected and fixed!")
            storage.saveContext()
        }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Playlist else { return false }
        return managedObject == object.managedObject
    }

}

extension Playlist: Identifyable {
    
    var identifier: String {
        return name
    }
    
}

extension Array where Element: Playlist {
    
    func filterRegualarPlaylists() -> [Element] {
        let filteredArray = self.filter { element in
            return !element.isSmartPlaylist
        }
        return filteredArray
    }

    func filterSmartPlaylists() -> [Element] {
        let filteredArray = self.filter { element in
            return element.isSmartPlaylist
        }
        return filteredArray
    }
    
}
