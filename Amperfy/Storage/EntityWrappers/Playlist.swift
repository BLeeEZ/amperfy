import Foundation
import CoreData
import os.log

public class Playlist: Identifyable {
    
    static let smartPlaylistIdPrefix = "smart_"
    static var typeName: String {
        return String(describing: Self.self)
    }
    
    let managedObject: PlaylistMO
    private let library: LibraryStorage
    
    init(library: LibraryStorage, managedObject: PlaylistMO) {
        self.library = library
        self.managedObject = managedObject
    }
    
    var identifier: String {
        return name
    }
    
    func getManagedObject(in context: NSManagedObjectContext, library: LibraryStorage) -> Playlist {
        let playlistMO = context.object(with: managedObject.objectID) as! PlaylistMO
        return Playlist(library: library, managedObject: playlistMO)
    }
    
    private var sortedPlaylistItems: [PlaylistItem] {
        var sortedItems = [PlaylistItem]()
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else {
            return sortedItems
        }
        sortedItems = itemsMO.lazy
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(library: library, managedObject: $0) }
        return sortedItems
    }
    
    private var sortedCachedPlaylistItems: [PlaylistItem] {
        var sortedCachedItems = [PlaylistItem]()
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else {
            return sortedCachedItems
        }
        sortedCachedItems = itemsMO.lazy
            .filter{ return $0.playable?.file != nil }
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(library: library, managedObject: $0) }
        return sortedCachedItems
    }
    
    var songCount: Int {
        get { return Int(managedObject.songCount) }
        set {
            guard Int16.isValid(value: newValue), managedObject.songCount != Int16(newValue) else { return }
            managedObject.songCount = Int16(newValue)
        }
    }
    var playables: [AbstractPlayable] {
        var sortedPlayables = [AbstractPlayable]()
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else {
            return sortedPlayables
        }
        sortedPlayables = itemsMO.lazy
            .sorted(by: { $0.order < $1.order })
            .compactMap{ $0.playable }
            .compactMap{ AbstractPlayable(managedObject: $0) }
        return sortedPlayables
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
            library.saveContext()
        }
    }
    var name: String {
        get {
            return managedObject.name ?? ""
        }
        set {
            if managedObject.name != newValue {
                managedObject.name = newValue
                library.saveContext()
            }
        }
    }
    var isSmartPlaylist: Bool {
        return id.hasPrefix(Self.smartPlaylistIdPrefix)
    }
    var lastPlayableIndex: Int {
        guard playables.count > 0 else { return 0 }
        return playables.count-1
    }

    var info: String {
        var infoText = "Name: " + name + "\n"
        infoText += "Count: " + String(sortedPlaylistItems.count) + "\n"
        infoText += "Playables:\n"
        for playlistItem in sortedPlaylistItems {
            infoText += String(playlistItem.order) + ": "
            if let playable = playlistItem.playable {
                infoText += playable.creatorName
                infoText += " - "
                infoText += playable.title
            } else {
                infoText += "NOT AVAILABLE"
            }
            infoText += "\n"
        }
        return infoText
    }
    
    func previousCachedItemIndex(downwardsFrom: Int) -> Int? {
        let cachedPlaylistItems = sortedCachedPlaylistItems
        guard downwardsFrom <= playables.count, !cachedPlaylistItems.isEmpty else {
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
    
    func previousCachedItemIndex(beginningAt: Int) -> Int? {
        return previousCachedItemIndex(downwardsFrom: beginningAt+1)
    }
    
    func nextCachedItemIndex(upwardsFrom: Int) -> Int? {
        let cachedPlaylistItems = sortedCachedPlaylistItems
        guard upwardsFrom < playables.count, !cachedPlaylistItems.isEmpty else {
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
    
    func nextCachedItemIndex(beginningAt: Int) -> Int? {
        return nextCachedItemIndex(upwardsFrom: beginningAt-1)
    }
    
    func insert(playables playablesToInsert: [AbstractPlayable], index insertIndex: Int = 0) {
        let localSortedPlaylistItems = sortedPlaylistItems
        guard insertIndex <= localSortedPlaylistItems.count && insertIndex >= 0, playablesToInsert.count > 0 else { return }
        let oldItemsAfterIndex = sortedPlaylistItems[insertIndex...]
        for localItem in oldItemsAfterIndex {
            localItem.order += playablesToInsert.count
        }
        for (index, playable) in playablesToInsert.enumerated() {
            createPlaylistItem(for: playable, customOrder: index + insertIndex)
        }
        songCount += playablesToInsert.count
        library.saveContext()
    }

    func append(playable: AbstractPlayable) {
        createPlaylistItem(for: playable)
        songCount += 1
        library.saveContext()
    }

    func append(playables playablesToAppend: [AbstractPlayable]) {
        for playable in playablesToAppend {
            createPlaylistItem(for: playable)
        }
        songCount += playablesToAppend.count
        library.saveContext()
    }

    private func createPlaylistItem(for playable: AbstractPlayable, customOrder: Int? = nil) {
        let playlistItem = library.createPlaylistItem()
        playlistItem.order = customOrder ?? managedObject.items!.count
        playlistItem.playlist = self
        playlistItem.playable = playable
    }

    func add(item: PlaylistItem) {
        songCount += 1
        managedObject.addToItems(item.managedObject)
    }
    
    func movePlaylistItem(fromIndex: Int, to: Int) {
        guard fromIndex >= 0, fromIndex < playables.count, to >= 0, to < playables.count, fromIndex != to else { return }
        
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
        
        library.saveContext()
    }
    
    func remove(at index: Int) {
        if index < sortedPlaylistItems.count {
            let itemToBeRemoved = sortedPlaylistItems[index]
            for item in sortedPlaylistItems {
                if item.order > index {
                    item.order = item.order - 1
                }
            }
            library.deletePlaylistItem(item: itemToBeRemoved)
            songCount -= 1
            library.saveContext()
        }
    }
    
    func remove(firstOccurrenceOfPlayable playable: AbstractPlayable) {
        for item in items {
            if item.playable?.id == playable.id {
                remove(at: Int(item.order))
                songCount -= 1
                break
            }
        }
    }
    
    func getFirstIndex(playable: AbstractPlayable) -> Int? {
        for item in items {
            if item.playable?.id == playable.id {
                return Int(item.order)
            }
        }
        return nil
    }
    
    func removeAllItems() {
        for item in sortedPlaylistItems {
            library.deletePlaylistItem(item: item)
        }
        songCount = 0
        library.saveContext()
    }
    
    func shuffle() {
        let localSortedPlaylistItems = sortedPlaylistItems
        let songCount = localSortedPlaylistItems.count
        guard songCount > 0 else { return }
        
        var shuffeldIndexes = [Int]()
        shuffeldIndexes += 0...songCount-1
        shuffeldIndexes = shuffeldIndexes.shuffled()
        
        for i in 0..<songCount {
            localSortedPlaylistItems[i].order = shuffeldIndexes[i]
        }
        library.saveContext()
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
            library.saveContext()
        }
    }

}

extension Playlist: PlayableContainable  {
    func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if songCount == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(songCount) Songs")
        }
        if isSmartPlaylist {
            infoContent.append("Smart Playlist")
        }
        if type == .long {
            infoContent.append("\(playables.reduce(0, {$0 + $1.duration}).asDurationString)")
        }
        return infoContent
    }
}

extension Playlist: Hashable, Equatable {
    public static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
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
