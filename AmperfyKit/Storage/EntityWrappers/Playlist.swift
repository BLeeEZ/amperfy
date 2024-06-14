//
//  Playlist.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import os.log
import UIKit
import PromiseKit

public class Playlist: Identifyable {
    
    static let smartPlaylistIdPrefix = "smart_"
    static var typeName: String {
        return String(describing: Self.self)
    }
    
    public let managedObject: PlaylistMO
    private let library: LibraryStorage
    private var kvoToken: NSKeyValueObservation?
    private var isInternalArrayUpdateNeeded = false
    
    public init(library: LibraryStorage, managedObject: PlaylistMO) {
        self.library = library
        self.managedObject = managedObject
        kvoToken = self.managedObject.observe(\.items, options: .new) { (playlist, change) in
            self.isInternalArrayUpdateNeeded = true
        }
    }
    
    deinit {
        kvoToken?.invalidate()
    }
    
    public var identifier: String {
        return name
    }
    
    public func getManagedObject(in context: NSManagedObjectContext, library: LibraryStorage) -> Playlist {
        let playlistMO = context.object(with: managedObject.objectID) as! PlaylistMO
        return Playlist(library: library, managedObject: playlistMO)
    }
    
    private var internalSortedPlaylistItems: [PlaylistItem]?
    private var internalSortedCachedPlaylistItems: [PlaylistItem]?
    private var internalPlayables: [AbstractPlayable]?
    
    private func checkIfUpdateIsNeeded() -> Bool {
        let managedObjectItemCount = managedObject.items?.count ?? 0
        
        guard let internalSortedPI = internalSortedPlaylistItems,
              let internalPlayables = internalPlayables,
              let internalSortedCachedPlaylistItems = internalSortedCachedPlaylistItems
        else { return true }
        
        let cachedPI = internalSortedPI.reduce(0){ $0 + (($1.playable?.isCached ?? false) ? 1 : 0) }
        
        return isInternalArrayUpdateNeeded ||
            (managedObjectItemCount != internalSortedPI.count) ||
            (managedObjectItemCount != internalPlayables.count) ||
            (cachedPI != internalSortedCachedPlaylistItems.count)
    }
    private func updateInternalArrays() {
        isInternalArrayUpdateNeeded = false
        updateSortedPlaylistItems()
        updateSortedCachedPlaylistItems()
        updateInternalPlayables()
    }
    private func updateSortedPlaylistItems() {
        guard let itemsMO = managedObject.items?.allObjects as? [PlaylistItemMO] else { return }
        internalSortedPlaylistItems = itemsMO
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(library: library, managedObject: $0) }
    } 
    private func updateSortedCachedPlaylistItems() {
        internalSortedCachedPlaylistItems = internalSortedPlaylistItems?.filter{ return $0.playable?.isCached ?? false }
    }
    private func updateInternalPlayables() {
        internalPlayables = internalSortedPlaylistItems?.compactMap{ $0.playable }
    }

    private var sortedPlaylistItems: [PlaylistItem] {
        if internalSortedPlaylistItems == nil || checkIfUpdateIsNeeded() { updateInternalArrays() }
        return internalSortedPlaylistItems ?? [PlaylistItem]()
    }
    
    private var sortedCachedPlaylistItems: [PlaylistItem] {
        if internalSortedCachedPlaylistItems == nil || checkIfUpdateIsNeeded() { updateInternalArrays() }
        return internalSortedCachedPlaylistItems ?? [PlaylistItem]()
    }
    public var items: [PlaylistItem] {
        return sortedPlaylistItems
    }
    public var artworkItems: [PlaylistItem] {
        guard let artworkItemsMO = managedObject.artworkItems?.allObjects as? [PlaylistItemMO] else { return [PlaylistItem]() }
        return artworkItemsMO
            .sorted(by: { $0.order < $1.order })
            .compactMap{ PlaylistItem(library: library, managedObject: $0) }
    }
    public func updateArtworkItems(isInitialUpdate: Bool) {
        guard !isInitialUpdate || songCount < 100 else { return }
        
        if isInitialUpdate {
            updateSortedPlaylistItems()
        } else if internalSortedPlaylistItems == nil || (internalSortedPlaylistItems?.count ?? 0) == 0, songCount < 100 {
            updateSortedPlaylistItems()
        }
        
        if let internalSortedPlaylistItems = internalSortedPlaylistItems {
            var updatedArtworkItems = [PlaylistItem]()
            for (index, playlistItem) in internalSortedPlaylistItems.enumerated() {
                if playlistItem.playable?.artwork != nil {
                    updatedArtworkItems.append(playlistItem)
                    if updatedArtworkItems.count >= 4 || index > 20 {
                        break
                    }
                }
            }
            let artworkItems = artworkItems
            if artworkItems != updatedArtworkItems {
                managedObject.artworkItems = nil
                for item in updatedArtworkItems {
                    managedObject.addToArtworkItems(item.managedObject)
                }
            }
        }
    }
    
    public var playables: [AbstractPlayable] {
        if internalPlayables == nil || checkIfUpdateIsNeeded() {
            updateInternalArrays()
        } else {
            updateInternalPlayables()
        }
        return internalPlayables ?? [AbstractPlayable]()
    }
    

    
    public var songCount: Int {
        get { return Int(managedObject.songCount) }
        set {
            guard Int16.isValid(value: newValue), managedObject.songCount != Int16(newValue) else { return }
            managedObject.songCount = Int16(newValue)
        }
    }
    public var remoteSongCount: Int {
        get { return Int(managedObject.remoteSongCount) }
        set {
            if Int16.isValid(value: newValue) {
                if managedObject.remoteSongCount != Int16(newValue) {
                    managedObject.remoteSongCount = Int16(newValue)
                }
                updateSongCount()
            }
        }
    }
    public func updateSongCount() {
        if let items = managedObject.items, items.count > 0, Int16.isValid(value: items.count) {
            managedObject.songCount = Int16(items.count)
        } else {
            // set songCount to remoteSongCount only if no songs are locally available
            managedObject.songCount = managedObject.remoteSongCount
        }
    }

    public var id: String {
        get {
            return managedObject.id
        }
        set {
            managedObject.id = newValue
            library.saveContext()
        }
    }
    public var name: String {
        get {
            return managedObject.name ?? ""
        }
        set {
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
                updateChangeDate()
                library.saveContext()
            }
        }
    }
    func updateAlphabeticSectionInitial(section: String) {
        let initial = section.sectionInitial
        if managedObject.alphabeticSectionInitial != initial {
            managedObject.alphabeticSectionInitial = initial
        }
    }
    public var playCount: Int {
        get { return Int(managedObject.playCount) }
        set {
            guard Int32.isValid(value: newValue), managedObject.playCount != Int32(newValue) else { return }
            managedObject.playCount = Int32(newValue)
        }
    }
    public var lastTimePlayed: Date? {
        get { return managedObject.lastPlayedDate }
        set { if managedObject.lastPlayedDate != newValue { managedObject.lastPlayedDate = newValue } }
    }
    public var changeDate: Date? {
        get { return managedObject.changeDate }
        set { if managedObject.changeDate != newValue { managedObject.changeDate = newValue } }
    }
    public var isSmartPlaylist: Bool {
        return id.hasPrefix(Self.smartPlaylistIdPrefix)
    }
    public var lastPlayableIndex: Int {
        guard playables.count > 0 else { return 0 }
        return playables.count-1
    }
    public var duration: Int {
        get { return Int(managedObject.duration) }
    }
    public var remoteDuration: Int {
        get { return Int(managedObject.remoteDuration) }
        set {
            if Int16.isValid(value: newValue), managedObject.remoteDuration != Int16(newValue) {
                managedObject.remoteDuration = Int16(newValue)
            }
            updateDuration()
        }
    }
    public func updateDuration() {
        if (managedObject.items?.count ?? 0) > 0 {
            let playablesDuration = playables.reduce(0){ $0 + $1.duration }
            if Int16.isValid(value: playablesDuration), managedObject.duration != Int16(playablesDuration) {
                managedObject.duration = Int16(playablesDuration)
            }
        } else {
            if managedObject.duration != managedObject.remoteDuration {
                managedObject.duration = managedObject.remoteDuration
            }
        }
    }
    private func updateDuration(byReducingDuration: Int) {
        if byReducingDuration > 0, duration >= byReducingDuration, Int16.isValid(value: byReducingDuration) {
            managedObject.duration -= Int16(byReducingDuration)
        }
    }
    private func updateDuration(byIncreasingDuration: Int) {
        if byIncreasingDuration > 0, Int16.isValid(value: byIncreasingDuration), Int16.isValid(value: duration + byIncreasingDuration) {
            managedObject.duration += Int16(byIncreasingDuration)
        }
    }

    public var info: String {
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
    
    public func previousCachedItemIndex(downwardsFrom: Int) -> Int? {
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
    
    public func previousCachedItemIndex(beginningAt: Int) -> Int? {
        return previousCachedItemIndex(downwardsFrom: beginningAt+1)
    }
    
    public func nextCachedItemIndex(upwardsFrom: Int) -> Int? {
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
    
    public func nextCachedItemIndex(beginningAt: Int) -> Int? {
        return nextCachedItemIndex(upwardsFrom: beginningAt-1)
    }
    
    public func insert(playables playablesToInsert: [AbstractPlayable], index insertIndex: Int = 0) {
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
        updateDuration(byIncreasingDuration: playablesToInsert.reduce(0){ $0 + $1.duration })
        updateArtworkItems(isInitialUpdate: false)
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    public func append(playable: AbstractPlayable) {
        createPlaylistItem(for: playable)
        songCount += 1
        updateChangeDate()
        updateDuration(byIncreasingDuration: playable.duration)
        updateArtworkItems(isInitialUpdate: false)
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    public func append(playables playablesToAppend: [AbstractPlayable]) {
        for playable in playablesToAppend {
            createPlaylistItem(for: playable)
        }
        songCount += playablesToAppend.count
        updateChangeDate()
        updateDuration(byIncreasingDuration: playablesToAppend.reduce(0){ $0 + $1.duration })
        updateArtworkItems(isInitialUpdate: false)
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }

    private func createPlaylistItem(for playable: AbstractPlayable, customOrder: Int? = nil) {
        let playlistItem = library.createPlaylistItem()
        playlistItem.order = customOrder ?? managedObject.items!.count
        playlistItem.playlist = self
        playlistItem.playable = playable
    }

    public func add(item: PlaylistItem) {
        songCount += 1
        updateChangeDate()
        updateDuration(byIncreasingDuration: item.playable?.duration ?? 0)
        managedObject.addToItems(item.managedObject)
        isInternalArrayUpdateNeeded = true
    }
    
    public func movePlaylistItem(fromIndex: Int, to: Int) {
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
        updateArtworkItems(isInitialUpdate: false)
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }
    
    public func remove(at index: Int) {
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
            updateDuration(byReducingDuration: itemToBeRemoved.playable?.duration ?? 0)
            updateArtworkItems(isInitialUpdate: false)
            library.saveContext()
            isInternalArrayUpdateNeeded = true
        }
    }
    
    public func remove(firstOccurrenceOfPlayable playable: AbstractPlayable) {
        for item in items {
            if item.playable?.id == playable.id {
                remove(at: Int(item.order))
                songCount -= 1
                break
            }
        }
        isInternalArrayUpdateNeeded = true
    }
    
    public func getFirstIndex(playable: AbstractPlayable) -> Int? {
        for item in items {
            if item.playable?.id == playable.id {
                return Int(item.order)
            }
        }
        return nil
    }
    
    public func removeAllItems() {
        for item in sortedPlaylistItems {
            library.deletePlaylistItem(item: item)
        }
        songCount = 0
        updateChangeDate()
        updateArtworkItems(isInitialUpdate: false)
        managedObject.duration = 0
        managedObject.remoteDuration = 0
        library.saveContext()
        isInternalArrayUpdateNeeded = true
    }
    
    public func shuffle() {
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
    
    public func updateChangeDate() {
        changeDate = Date()
    }

    public func ensureConsistentItemOrder() {
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
    
    public func getDefaultImage(theme: ThemePreference) -> UIImage  {
        return UIImage.getGeneratedArtwork(theme: theme, artworkType: .playlist)
    }

}

extension Playlist: PlayableContainable  {
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
        var infoContent = [String]()
        if songCount == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(songCount) Songs")
        }
        if isSmartPlaylist {
            infoContent.append("Smart Playlist")
        }
        if details.type == .short, duration > 0 {
            infoContent.append("\(duration.asDurationShortString)")
        }
        if details.type == .long {
            if isCompletelyCached {
                infoContent.append("Cached")
            }
            let completeDuration = playables.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationShortString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playContextType: PlayerMode { return .music }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        return librarySyncer.syncDown(playlist: self)
    }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        return Promise<Void>(error: BackendError.notSupported)
    }
    public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
        let artworkItems = artworkItems
        
        if artworkItems.isEmpty {
            return ArtworkCollection(defaultImage: getDefaultImage(theme: theme), singleImageEntity: nil)
        } else if artworkItems.count == 1 {
            return ArtworkCollection(defaultImage: getDefaultImage(theme: theme), singleImageEntity: artworkItems[0].playable)
        } else {
            let quadImages = artworkItems.compactMap{ return $0.playable }.prefix(upToAsArray: 4)
            return ArtworkCollection(defaultImage: getDefaultImage(theme: theme), singleImageEntity: artworkItems[0].playable, quadImageEntity: quadImages)
        }
    }
    public func playedViaContext() {
        lastTimePlayed = Date()
        playCount += 1
    }
    public var containerIdentifier: PlayableContainerIdentifier { return PlayableContainerIdentifier(type: .playlist, objectID: managedObject.objectID.uriRepresentation().absoluteString) }
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
