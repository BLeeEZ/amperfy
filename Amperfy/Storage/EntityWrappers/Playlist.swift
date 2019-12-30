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
    
    private var sortedPlaylistElements: [PlaylistElement] {
        var sortedElements = [PlaylistElement]()
        let sortedElementsMO = (managedObject.entries!.allObjects as! [PlaylistElementMO]).sorted(by: { $0.order < $1.order })
        for elementMO in sortedElementsMO {
            sortedElements.append(PlaylistElement(storage: storage, managedObject: elementMO))
        }
        return sortedElements
    }
    private var sortedCachedPlaylistElements: [PlaylistElement] {
        let cachedElementsMO = managedObject.entries!.filter{ entry in
            let element = entry as! PlaylistElementMO
            return element.song?.fileDataContainer != nil
        }
        let sortedElementsMO = (cachedElementsMO as! [PlaylistElementMO]).sorted(by: { $0.order < $1.order })
        
        var sortedCachedElements = [PlaylistElement]()
        for elementMO in sortedElementsMO {
            sortedCachedElements.append(PlaylistElement(storage: storage, managedObject: elementMO))
        }
        return sortedCachedElements
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
    var lastSongIndex: Int {
        guard songs.count > 0 else { return 0 }
        return songs.count-1
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    var info: String {
        var infoText = "Name: " + name + "\n"
        infoText += "Count: " + String(sortedPlaylistElements.count) + "\n"
        infoText += "Songs:\n"
        for playlistElement in sortedPlaylistElements {
            infoText += String(playlistElement.order) + ": "
            if let song = playlistElement.song {
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
        playlistElement.order = managedObject.entries!.count
        playlistElement.playlist = self
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
        managedObject.addToEntries(entry.managedObject)
    }
    
    func movePlaylistSong(fromIndex: Int, to: Int) {
        if fromIndex < songs.count, to < songs.count, fromIndex != to {
            let localSortedPlaylistElements = sortedPlaylistElements
            let targetOrder = localSortedPlaylistElements[to].order
            if fromIndex < to {
                for i in fromIndex+1...to {
                    localSortedPlaylistElements[i].order = localSortedPlaylistElements[i].order - 1
                }
            } else {
                for i in to...fromIndex-1 {
                    localSortedPlaylistElements[i].order = localSortedPlaylistElements[i].order + 1
                }
            }
            localSortedPlaylistElements[fromIndex].order = targetOrder
            
            storage.saveContext()
            ensureConsistentEntityOrder()
        }
    }
    
    func remove(at index: Int) {
        if index < sortedPlaylistElements.count {
            let elementToBeRemoved = sortedPlaylistElements[index]
            for entry in sortedPlaylistElements {
                if entry.order > index {
                    entry.order = entry.order - 1
                }
            }
            storage.deletePlaylistElement(element: elementToBeRemoved)
            storage.saveContext()
            ensureConsistentEntityOrder()
        }
    }
    
    func remove(firstOccurrenceOfSong song: Song) {
        for entry in entries {
            if entry.song?.id == song.id {
                remove(at: Int(entry.order))
                break
            }
        }
    }
    
    func getFirstIndex(song: Song) -> Int? {
        for entry in entries {
            if entry.song?.id == song.id {
                return Int(entry.order)
            }
        }
        return nil
    }
    
    func removeAllSongs() {
        for entry in sortedPlaylistElements {
            storage.deletePlaylistElement(element: entry)
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

    private func ensureConsistentEntityOrder() {
        var hasInconsistencyDetected = false
        for (index, element) in sortedPlaylistElements.enumerated() {
            if element.order != index {
                os_log(.debug, "Playlist inconsistency detected! Order: %d  Index: %d", element.order, index)
                element.order = index
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

