import Foundation
import CoreData
import os.log

public class Playlist {
    
    let managedPlaylist: PlaylistManaged
    private let storage: LibraryStorage
    private var sortedPlaylistElements: [PlaylistElement] {
        return managedPlaylist.sortedByOrder
    }
    private var sortedCachedPlaylistElements: [PlaylistElement] {
        let cachedSongs = managedPlaylist.entries!.filter{ entry in
            let element = entry as! PlaylistElement
            if element.song?.data == nil {
                return false
            }
            return true
        }
        return (cachedSongs as! [PlaylistElement]).sorted(by: { $0.order < $1.order })
    }
    
    var songs: [Song] {
        var songArray = [Song]()
        for playlistElement in sortedPlaylistElements {
            if let song = playlistElement.song {
                songArray.append(song)
            }
        }
        return songArray
    }
    var entries: [PlaylistElement] {
        return sortedPlaylistElements
    }
    var id: Int32 {
        get {
            return managedPlaylist.id
        }
        set {
            managedPlaylist.id = newValue
            storage.saveContext()
        }
    }
    var name: String {
        get {
            return managedPlaylist.name ?? ""
        }
        set {
            managedPlaylist.name = newValue
            storage.saveContext()
        }
    }
    var randomSongIndex: Int {
        return Int.random(in: 0..<songs.count)
    }
    var randomCachedSongIndex: Int? {
        return nextCachedSongIndex(beginningAt: Int.random(in: 0..<sortedCachedPlaylistElements.count))
    }
    var lastSongIndex: Int {
        guard songs.count > 0 else { return 0 }
        return songs.count-1
    }
    
    var hasCachedSongs: Bool {
        for song in songs {
            if song.data != nil {
                return true
            }
        }
        return false
    }
    
    init(storage: LibraryStorage, managedPlaylist: PlaylistManaged) {
        self.storage = storage
        self.managedPlaylist = managedPlaylist
    }
    
    func previousCachedSongIndex(downwardsFrom: Int) -> Int? {
        let cachedPlaylistElements = sortedCachedPlaylistElements
        guard downwardsFrom <= songs.count, !cachedPlaylistElements.isEmpty else {
            return nil
        }
        var previousIndex: Int? = nil
        for element in cachedPlaylistElements.reversed() {
            if element.order < downwardsFrom {
                previousIndex = Int(element.order)
                break
            }
        }
        return previousIndex
    }
    
    func previousCachedSongIndex(beginningAt: Int) -> Int? {
        return previousCachedSongIndex(downwardsFrom: beginningAt+1)
    }
    
    func nextCachedSongIndex(upwardsFrom: Int) -> Int? {
        let cachedPlaylistElements = sortedCachedPlaylistElements
        guard upwardsFrom < songs.count, !cachedPlaylistElements.isEmpty else {
            return nil
        }
        var nextIndex: Int? = nil
        for element in cachedPlaylistElements {
            if element.order > upwardsFrom {
                nextIndex = Int(element.order)
                break
            }
        }
        return nextIndex
    }
    
    func nextCachedSongIndex(beginningAt: Int) -> Int? {
        return nextCachedSongIndex(upwardsFrom: beginningAt-1)
    }
    
    func append(song: Song) {
        let playlistElement = storage.createPlaylistElement()
        playlistElement.order = Int32(managedPlaylist.entries!.count)
        playlistElement.playlist = managedPlaylist
        playlistElement.song = song
        storage.saveContext()
        ensureConsistentEntityOrder()
    }

    func append(songs songsToAppend: [Song]) {
        for song in songsToAppend {
            append(song: song)
        }
    }

    func add(entry: PlaylistElement) {
        entry.playlist = managedPlaylist
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        if fromIndex < songs.count, to < songs.count {
            let fromEntity = sortedPlaylistElements[fromIndex]
            let toEntity = sortedPlaylistElements[to]
            
            let fromEntityOrder = fromEntity.order
            fromEntity.order = toEntity.order
            toEntity.order = fromEntityOrder
            storage.saveContext()
            ensureConsistentEntityOrder()
        }
    }
    
    func remove(at index: Int) {
        if index < sortedPlaylistElements.count {
            let elementToBeRemoved = sortedPlaylistElements[index]
            for entry in managedPlaylist.entries!.allObjects as! [PlaylistElement] {
                if entry.order > index {
                    entry.order = entry.order - 1
                }
            }
            storage.deletePlaylistElement(element: elementToBeRemoved)
            storage.saveContext()
            ensureConsistentEntityOrder()
        }
    }
    
    func removeAllSongs() {
        for entry in managedPlaylist.entries!.allObjects as! [PlaylistElement] {
            storage.deletePlaylistElement(element: entry)
        }
        storage.saveContext()
    }

    private func ensureConsistentEntityOrder() {
        var hasInconsistencyDetected = false
        for (index, element) in sortedPlaylistElements.enumerated() {
            if element.order != index {
                os_log(.debug, "Playlist inconsistency detected! Order: %d  Index: %d", element.order, index)
                element.order = Int32(index)
                hasInconsistencyDetected = true
            }
        }
        if hasInconsistencyDetected {
            storage.saveContext()
        }
    }
}

extension Playlist: Identifyable {
    
    var identifier: String {
        return name
    }
    
}

