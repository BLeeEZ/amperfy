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

import Collections
import CoreData
import Foundation
import os.log
import UIKit

// MARK: - Playlist

public class Playlist: Identifyable {
  static let smartPlaylistIdPrefix = "smart_"
  static var typeName: String {
    String(describing: Self.self)
  }

  static let artworkItemMaxLookCount = 20

  public let managedObject: PlaylistMO
  private let library: LibraryStorage

  public init(library: LibraryStorage, managedObject: PlaylistMO) {
    self.library = library
    self.managedObject = managedObject
  }

  public var identifier: String {
    name
  }

  public var items: [PlaylistItem] {
    managedObject.items.compactMap { PlaylistItem(library: library, managedObject: $0) }
  }

  public var artworkItems: [PlaylistItem] {
    managedObject.artworkItems.compactMap { PlaylistItem(library: library, managedObject: $0) }
  }

  public func updateArtworkItems() {
    var updatedArtworkItems = [PlaylistItemMO]()
    for (index, playlistItem) in managedObject.items.enumerated() {
      if playlistItem.playable.artwork != nil {
        updatedArtworkItems.append(playlistItem)
        if updatedArtworkItems.count >= 4 || index > Self.artworkItemMaxLookCount {
          break
        }
      }
    }
    if managedObject.artworkItems != updatedArtworkItems {
      for artworkItem in artworkItems {
        managedObject.removeFromArtworkItems(artworkItem.managedObject)
      }
      for artworkItem in updatedArtworkItems {
        managedObject.addToArtworkItems(artworkItem)
      }
    }
  }

  public var playables: [AbstractPlayable] {
    managedObject.items.compactMap { AbstractPlayable(managedObject: $0.playable) }
  }

  public func getPlayable(at: Int) -> AbstractPlayable? {
    guard at < managedObject.items.count else { return nil }
    return AbstractPlayable(managedObject: managedObject.items[at].playable)
  }

  public func getPlayables(from: Int, to: Int? = nil) -> [AbstractPlayable] {
    guard !managedObject.items.isEmpty else { return [AbstractPlayable]() }
    let end = to ?? managedObject.items.count - 1
    guard from >= 0, end >= 0, from <= end,
          end < managedObject.items.count else { return [AbstractPlayable]() }
    return managedObject.items[from ... end]
      .compactMap { AbstractPlayable(managedObject: $0.playable) }
  }

  /// returns number of playables that are already contained in playlist
  public func contains(playables playablesToCheck: [AbstractPlayable])
    -> OrderedSet<AbstractPlayable> {
    let playableSet = OrderedSet<AbstractPlayable>(playables)
    let playablesToCheckSet = OrderedSet<AbstractPlayable>(playablesToCheck)
    return playableSet.intersection(playablesToCheckSet)
  }

  /// return a set of playables that are not already part of this playlist
  public func notContaines(playables playablesToCheck: [AbstractPlayable])
    -> OrderedSet<AbstractPlayable> {
    let playableSet = OrderedSet<AbstractPlayable>(playables)
    let playablesToCheckSet = OrderedSet<AbstractPlayable>(playablesToCheck)
    return playablesToCheckSet.subtracting(playableSet)
  }

  public var songCount: Int {
    let moSongCount = Int(managedObject.songCount)
    return moSongCount != 0 ? moSongCount : remoteSongCount
  }

  public var remoteSongCount: Int {
    get { Int(managedObject.remoteSongCount) }
    set {
      if Int16.isValid(value: newValue), managedObject.remoteSongCount != Int16(newValue) {
        managedObject.remoteSongCount = Int16(newValue)
      }
    }
  }

  public var id: String {
    get {
      managedObject.id
    }
    set {
      managedObject.id = newValue
      library.saveContext()
    }
  }

  public var account: Account? {
    get {
      guard let accountMO = managedObject.account else { return nil }
      return Account(managedObject: accountMO)
    }
    set {
      if managedObject.account != newValue?
        .managedObject { managedObject.account = newValue?.managedObject }
    }
  }

  public var name: String {
    get {
      managedObject.name ?? ""
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
    get { Int(managedObject.playCount) }
    set {
      guard Int32.isValid(value: newValue),
            managedObject.playCount != Int32(newValue) else { return }
      managedObject.playCount = Int32(newValue)
    }
  }

  public var lastTimePlayed: Date? {
    get { managedObject.lastPlayedDate }
    set { if managedObject.lastPlayedDate != newValue { managedObject.lastPlayedDate = newValue } }
  }

  public var changeDate: Date? {
    get { managedObject.changeDate }
    set { if managedObject.changeDate != newValue { managedObject.changeDate = newValue } }
  }

  public var isSmartPlaylist: Bool {
    id.hasPrefix(Self.smartPlaylistIdPrefix)
  }

  public var lastPlayableIndex: Int {
    guard !playables.isEmpty else { return 0 }
    return playables.count - 1
  }

  public var isCached: Bool {
    get { managedObject.isCached }
    set {
      if managedObject.isCached != newValue {
        managedObject.isCached = newValue
      }
    }
  }

  public var duration: Int { Int(managedObject.duration) }

  public var remoteDuration: Int {
    get { Int(managedObject.remoteDuration) }
    set {
      if managedObject.remoteDuration != Int64(newValue) {
        managedObject.remoteDuration = Int64(newValue)
      }
      if managedObject.duration != Int64(newValue) {
        managedObject.duration = Int64(newValue)
      }
    }
  }

  private func updateDuration(byReducingDuration: Int) {
    if byReducingDuration > 0, duration >= byReducingDuration {
      managedObject.duration -= Int64(byReducingDuration)
    }
  }

  private func updateDuration(byIncreasingDuration: Int) {
    if byIncreasingDuration > 0 {
      managedObject.duration += Int64(byIncreasingDuration)
    }
  }

  public var info: String {
    var infoText = "Name: " + name + "\n"
    infoText += "Count: " + String(songCount) + "\n"
    infoText += "Playables:\n"
    for playlistItem in managedObject.items {
      infoText += String(playlistItem.order) + ": "
      let playable = playlistItem.playable
      infoText += playable.title ?? ""
      infoText += "\n"
    }
    return infoText
  }

  public func append(playable: AbstractPlayable) {
    createAndAppendPlaylistItem(for: playable)
    updateChangeDate()
    updateDuration(byIncreasingDuration: playable.duration)
    updateArtworkItems()
    library.saveContext()
  }

  public func append(playables playablesToAppend: [AbstractPlayable]) {
    for playable in playablesToAppend {
      createAndAppendPlaylistItem(for: playable)
    }
    updateChangeDate()
    updateDuration(byIncreasingDuration: playablesToAppend.reduce(0) { $0 + $1.duration })
    updateArtworkItems()
    library.saveContext()
  }

  public func createAndAppendPlaylistItem(for playable: AbstractPlayable) {
    let playlistItem = library.createPlaylistItem(playable: playable)
    let lastPlaylistItemOrder = managedObject.items.last?.order ?? Int32(managedObject.items.count)
    playlistItem.managedObject.order = lastPlaylistItemOrder + PlaylistItemMO.orderDistance
    managedObject.addToItems(playlistItem.managedObject)
  }

  private func createAndInsertPlaylistItem(
    for playable: AbstractPlayable,
    atIndex: Int,
    withOrder: Int32
  ) {
    let playlistItem = library.createPlaylistItem(playable: playable)
    playlistItem.playable = playable
    playlistItem.managedObject.order = withOrder
    managedObject.insertIntoItems(playlistItem.managedObject, at: atIndex)
  }

  public func add(item: PlaylistItem) {
    updateChangeDate()
    updateDuration(byIncreasingDuration: item.playable.duration)
    managedObject.addToItems(item.managedObject)
  }

  public func reassignOrder() {
    for (index, item) in managedObject.items.enumerated() {
      item.order = Int32(index + 1) * PlaylistItemMO.orderDistance
    }
  }

  private func createEvenlySpreadIndicesInRangeOffset(indexCount: Int, range: Int) -> [Int32] {
    var spreadIndices = [Int32]()
    let rangeArray = Array(1 ... Int32(indexCount))
    if indexCount == range {
      spreadIndices = rangeArray
    } else {
      let availableSplitSpace = range - indexCount
      let minDiffBetweenIndex = availableSplitSpace / (indexCount + 1)
      if minDiffBetweenIndex > 0 {
        // it is possible to have at least one empty slot between the items
        for index in rangeArray {
          spreadIndices.append(index * Int32(minDiffBetweenIndex + 1))
        }

      } else {
        let spaceBeforeAndAfterItems = (range - indexCount) / 2
        for index in rangeArray {
          spreadIndices.append(index + Int32(spaceBeforeAndAfterItems))
        }
      }
    }
    assert(spreadIndices.count == indexCount)
    assert(spreadIndices.first! >= 0)
    assert(spreadIndices.last! <= range)
    return spreadIndices
  }

  /// nil as return value -> no free space left
  private func getOrdersToInsert(at: Int, itemToInsertCount: Int, isMove: Bool) -> [Int32]? {
    assert(at <= (isMove ? managedObject.items.count - 1 : managedObject.items.count))
    var orders = [Int32]()
    if at == 0 {
      if managedObject.items.isEmpty {
        return Array(1 ... Int32(itemToInsertCount))
          .compactMap { $0 * PlaylistItemMO.orderDistance }
      } else if managedObject.items[0].order < itemToInsertCount {
        // there is no space left to insert
        return nil
      } else {
        let spreadOrders = createEvenlySpreadIndicesInRangeOffset(
          indexCount: itemToInsertCount,
          range: Int(managedObject.items[0].order)
        )
        orders = spreadOrders.compactMap { $0 - 1 }
        assert(orders.count == itemToInsertCount)
      }
    } else if at == (isMove ? managedObject.items.count - 1 : managedObject.items.count) {
      // last playlist item
      let lastOrder = managedObject.items.last!.order
      for index in 0 ... Int32(itemToInsertCount - 1) {
        orders.append(lastOrder + ((index + 1) * PlaylistItemMO.orderDistance))
      }
      assert(orders.count == itemToInsertCount)
    } else {
      // somewhere in the array
      let oneBeforeToIndex = at - 1
      let oneBeforeToItemMO = managedObject.items[oneBeforeToIndex]
      let targetItemMO = managedObject.items[at]
      let spaceToInsert = targetItemMO.order - oneBeforeToItemMO.order - 1
      if spaceToInsert < itemToInsertCount {
        // there is no space left to insert
        return nil
      } else {
        let spreadOrders = createEvenlySpreadIndicesInRangeOffset(
          indexCount: itemToInsertCount,
          range: Int(spaceToInsert)
        )
        orders = spreadOrders.compactMap { oneBeforeToItemMO.order + $0 }
        assert(orders.count == itemToInsertCount)
      }
    }
    return orders
  }

  public func insert(playables playablesToInsert: [AbstractPlayable], index insertIndex: Int = 0) {
    guard insertIndex <= managedObject.items.count, insertIndex >= 0,
          !playablesToInsert.isEmpty else { return }

    let insertationCount = playablesToInsert.count
    let spreadOrders = getOrdersToInsert(
      at: insertIndex,
      itemToInsertCount: insertationCount,
      isMove: false
    )

    for (index, playable) in playablesToInsert.enumerated() {
      createAndInsertPlaylistItem(
        for: playable,
        atIndex: index + insertIndex,
        withOrder: spreadOrders?[index] ?? Int32(0)
      )
    }
    if spreadOrders == nil {
      reassignOrder()
    }

    updateChangeDate()
    updateDuration(byIncreasingDuration: playablesToInsert.reduce(0) { $0 + $1.duration })
    if insertIndex < Self.artworkItemMaxLookCount {
      updateArtworkItems()
    }
    library.saveContext()
  }

  public func movePlaylistItem(fromIndex: Int, to: Int) {
    guard fromIndex >= 0, fromIndex < managedObject.items.count, to >= 0,
          to < managedObject.items.count, fromIndex != to else { return }

    let fromItemMO = managedObject.items[fromIndex]
    let newOrders = getOrdersToInsert(at: to, itemToInsertCount: 1, isMove: true)
    assert(newOrders == nil || newOrders?.count == 1)
    managedObject.moveInsideItems(fromIndex: fromIndex, to: to)
    if let newOrder = newOrders?.first {
      fromItemMO.order = newOrder
    } else {
      reassignOrder()
    }

    updateChangeDate()
    if fromIndex < Self.artworkItemMaxLookCount || to < Self.artworkItemMaxLookCount {
      updateArtworkItems()
    }
    updateArtworkItems()
    library.saveContext()
  }

  public func remove(at index: Int) {
    guard index < managedObject.items.count else { return }
    let itemToBeRemovedMO = managedObject.items[index]
    managedObject.removeFromItems(at: index)
    library.deletePlaylistItemMO(item: itemToBeRemovedMO)

    updateChangeDate()
    updateDuration(byReducingDuration: Int(itemToBeRemovedMO.playable.combinedDuration))
    if index < Self.artworkItemMaxLookCount {
      updateArtworkItems()
    }
    library.saveContext()
  }

  public func remove(firstOccurrenceOfPlayable playable: AbstractPlayable) {
    let targetPlayableMO = playable.playableManagedObject
    if let targetIndex = managedObject.items
      .firstIndex(where: { $0.playable == targetPlayableMO }) {
      remove(at: targetIndex)
    }
  }

  public func getFirstIndex(item: PlaylistItem) -> Int? {
    let itemMO = item.managedObject
    return managedObject.items.firstIndex(where: { $0 == itemMO })
  }

  public func getFirstIndex(playable: AbstractPlayable) -> Int? {
    let targetPlayableMO = playable.playableManagedObject
    return managedObject.items.firstIndex(where: { $0.playable == targetPlayableMO })
  }

  public func removeAllItems() {
    managedObject.removeAllItems()
    updateChangeDate()
    updateArtworkItems()
    managedObject.duration = 0
    managedObject.remoteDuration = 0
    library.saveContext()
  }

  public func shuffle() {
    guard !managedObject.items.isEmpty else { return }

    var shuffeldIndexes = [Int]()
    shuffeldIndexes += 0 ... Int(managedObject.items.count - 1)
    shuffeldIndexes = shuffeldIndexes.shuffled()
    assert(shuffeldIndexes.count == managedObject.items.count)

    let orgItems = managedObject.items.compactMap { AbstractPlayable(managedObject: $0.playable) }
    assert(shuffeldIndexes.count == orgItems.count)
    managedObject.removeAllItems()
    for i in 0 ..< orgItems.count {
      createAndAppendPlaylistItem(for: orgItems[shuffeldIndexes[i]])
    }
    assert(shuffeldIndexes.count == managedObject.items.count)
    library.saveContext()
  }

  public func updateChangeDate() {
    changeDate = Date()
  }

  @MainActor
  public func getDefaultArtworkType() -> ArtworkType {
    .playlist
  }
}

// MARK: PlayableContainable

extension Playlist: PlayableContainable {
  public var subtitle: String? { nil }
  public var subsubtitle: String? { nil }
  public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
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
      if isCached {
        infoContent.append("Cached")
      }
      if duration > 0 {
        infoContent.append("\(duration.asDurationShortString)")
      }
      if details.isShowDetailedInfo {
        infoContent.append("ID: \(!id.isEmpty ? id : "-")")
      }
    }
    return infoContent
  }

  public var playContextType: PlayerMode { .music }
  @MainActor
  public func fetchFromServer(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws {
    try await librarySyncer.syncDown(playlist: self)
  }

  @MainActor
  public func remoteToggleFavorite(syncer: LibrarySyncer) async throws {
    throw BackendError.notSupported
  }

  public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
    let artworkItems = artworkItems

    if artworkItems.isEmpty {
      return ArtworkCollection(defaultArtworkType: getDefaultArtworkType(), singleImageEntity: nil)
    } else if artworkItems.count == 1 {
      return ArtworkCollection(
        defaultArtworkType: getDefaultArtworkType(),
        singleImageEntity: artworkItems[0].playable
      )
    } else {
      let quadImages = artworkItems.compactMap { $0.playable }.prefix(upToAsArray: 4)
      return ArtworkCollection(
        defaultArtworkType: getDefaultArtworkType(),
        singleImageEntity: artworkItems[0].playable,
        quadImageEntity: quadImages
      )
    }
  }

  public func playedViaContext() {
    lastTimePlayed = Date()
    playCount += 1
  }

  public var containerIdentifier: PlayableContainerIdentifier { PlayableContainerIdentifier(
    type: .playlist,
    objectID: managedObject.objectID.uriRepresentation().absoluteString
  ) }
}

// MARK: Hashable, Equatable

extension Playlist: Hashable, Equatable {
  public static func == (lhs: Playlist, rhs: Playlist) -> Bool {
    lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(managedObject)
  }
}

extension Array where Element: Playlist {
  func filterRegualarPlaylists() -> [Element] {
    let filteredArray = filter { element in
      !element.isSmartPlaylist
    }
    return filteredArray
  }

  func filterSmartPlaylists() -> [Element] {
    let filteredArray = filter { element in
      element.isSmartPlaylist
    }
    return filteredArray
  }
}
