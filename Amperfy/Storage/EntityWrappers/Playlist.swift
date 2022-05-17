import Foundation
import CoreData
import os.log
import UIKit

public class Playlist: Identifyable {
    
    static let smartPlaylistIdPrefix = "smart_"
    static var typeName: String {
        return String(describing: Self.self)
    }
    
    let managedObject: PlaylistMO
    private let library: LibraryStorage
    private var kvoToken: NSKeyValueObservation?
    private var isInternalArrayUpdateNeeded = false
    
    init(library: LibraryStorage, managedObject: PlaylistMO) {
        self.library = library
        self.managedObject = managedObject
        kvoToken = self.managedObject.observe(\.items, options: .new) { (playlist, change) in
            self.isInternalArrayUpdateNeeded = true
        }
    }
    
    deinit {
        kvoToken?.invalidate()
    }
    
    var identifier: String {
        return name
    }
    
    func getManagedObject(in context: NSManagedObjectContext, library: LibraryStorage) -> Playlist {
        let playlistMO = context.object(with: managedObject.objectID) as! PlaylistMO
        return Playlist(library: library, managedObject: playlistMO)
    }
    
    private var internalSortedPlaylistItems: [PlaylistItem]?
    private func updateSortedPlaylistItems() {
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else { return }
        internalSortedPlaylistItems = itemsMO
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(library: library, managedObject: $0) }
    }
    private var sortedPlaylistItems: [PlaylistItem] {
        if internalSortedPlaylistItems == nil || isInternalArrayUpdateNeeded { updateInternalArrays() }
        return internalSortedPlaylistItems ?? [PlaylistItem]()
    }
    
    private var internalSortedCachedPlaylistItems: [PlaylistItem]?
    private func updateSortedCachedPlaylistItems() {
        internalSortedCachedPlaylistItems = sortedPlaylistItems.filter{ return $0.playable?.isCached ?? false }
    }
    private var sortedCachedPlaylistItems: [PlaylistItem] {
        if internalSortedCachedPlaylistItems == nil || isInternalArrayUpdateNeeded { updateInternalArrays() }
        return internalSortedCachedPlaylistItems ?? [PlaylistItem]()
    }
    var items: [PlaylistItem] {
        return sortedPlaylistItems
    }
    

    private var internalPlayables: [AbstractPlayable]?
    private func updateInternalPlayables() {
        internalPlayables = sortedPlaylistItems.compactMap{ $0.playable }
    }
    var playables: [AbstractPlayable] {
        if internalPlayables == nil || isInternalArrayUpdateNeeded { updateInternalArrays() }
        updateInternalPlayables()
        return internalPlayables ?? [AbstractPlayable]()
    }
    
    private func updateInternalArrays() {
        isInternalArrayUpdateNeeded = false
        updateSortedPlaylistItems()
        updateSortedCachedPlaylistItems()
        updateInternalPlayables()
    }
    
    var songCount: Int {
        get { return Int(managedObject.songCount) }
        set {
            guard Int16.isValid(value: newValue), managedObject.songCount != Int16(newValue) else { return }
            managedObject.songCount = Int16(newValue)
        }
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
                updateChangeDate()
                library.saveContext()
            }
        }
    }
    var playCount: Int {
        get { return Int(managedObject.playCount) }
        set {
            guard Int32.isValid(value: newValue), managedObject.playCount != Int32(newValue) else { return }
            managedObject.playCount = Int32(newValue)
        }
    }
    var lastTimePlayed: Date? {
        get { return managedObject.lastPlayedDate }
        set { if managedObject.lastPlayedDate != newValue { managedObject.lastPlayedDate = newValue } }
    }
    var changeDate: Date? {
        get { return managedObject.changeDate }
        set { if managedObject.changeDate != newValue { managedObject.changeDate = newValue } }
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
        updateChangeDate()
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    func append(playable: AbstractPlayable) {
        createPlaylistItem(for: playable)
        songCount += 1
        updateChangeDate()
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    func append(playables playablesToAppend: [AbstractPlayable]) {
        for playable in playablesToAppend {
            createPlaylistItem(for: playable)
        }
        songCount += playablesToAppend.count
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    private func createPlaylistItem(for playable: AbstractPlayable, customOrder: Int? = nil) {
        let playlistItem = library.createPlaylistItem()
        playlistItem.order = customOrder ?? managedObject.items!.count
        playlistItem.playlist = self
        playlistItem.playable = playable
    }

    func add(item: PlaylistItem) {
        songCount += 1
        updateChangeDate()
        managedObject.addToItems(item.managedObject)
        isInternalArrayUpdateNeeded = true
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
        
        updateChangeDate()
        library.saveContext()
        isInternalArrayUpdateNeeded = true
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
            updateChangeDate()
            library.saveContext()
            isInternalArrayUpdateNeeded = true
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
        isInternalArrayUpdateNeeded = true
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
        updateChangeDate()
        library.saveContext()
        isInternalArrayUpdateNeeded = true
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
        isInternalArrayUpdateNeeded = true
    }
    
    func updateChangeDate() {
        changeDate = Date()
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
            isInternalArrayUpdateNeeded = true
        }
    }
    
    var defaultImage: UIImage {
        return UIImage.playlistArtwork
    }

}

extension Playlist: PlayableContainable  {
    var subtitle: String? { return nil }
    var subsubtitle: String? { return nil }
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
            let completeDuration = playables.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationString)")
            }
        }
        return infoContent
    }
    var playContextType: PlayerMode { return .music }
    func fetchFromServer(inContext context: NSManagedObjectContext, backendApi: BackendApi, settings: PersistentStorage.Settings, playableDownloadManager: DownloadManageable) {
        let syncer = backendApi.createLibrarySyncer()
        let library = LibraryStorage(context: context)
        let playlistAsync = getManagedObject(in: context, library: library)
        syncer.syncDown(playlist: playlistAsync, library: library)
    }
    var artworkCollection: ArtworkCollection {
        if songCount < 500 {
            let customArtworkSongs = playables.filterCustomArt()
            if customArtworkSongs.isEmpty {
                return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: nil)
            } else if customArtworkSongs.count == 1 {
                return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: customArtworkSongs[0])
            } else {
                let quadImages = Array(customArtworkSongs.prefix(4))
                return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: customArtworkSongs[0], quadImageEntity: quadImages)
            }
        } else {
            return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: nil)
        }
    }
    func playedViaContext() {
        lastTimePlayed = Date()
        playCount += 1
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
