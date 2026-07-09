//
//  SavedQueue.swift
//  AmperfyKit
//
//  Created by Amperfy Contributors on 08.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation

// MARK: - SavedQueue

public class SavedQueue {
  public static var typeName: String { String(describing: Self.self) }

  public let managedObject: SavedQueueMO
  private let library: LibraryStorage

  public init(library: LibraryStorage, managedObject: SavedQueueMO) {
    self.library = library
    self.managedObject = managedObject
  }

  public var name: String {
    get { managedObject.name ?? "" }
    set { managedObject.name = newValue }
  }

  public var lastUsedAt: Date {
    get { managedObject.lastUsedAt ?? Date.distantPast }
    set { managedObject.lastUsedAt = newValue }
  }

  public var currentIndex: Int {
    get { Int(managedObject.currentIndex) }
    set { managedObject.currentIndex = Int32(newValue) }
  }

  public var isShuffle: Bool {
    get { managedObject.isShuffle }
    set { managedObject.isShuffle = newValue }
  }

  public var repeatMode: RepeatMode {
    get { RepeatMode(rawValue: managedObject.repeatMode) ?? .off }
    set { managedObject.repeatMode = newValue.rawValue }
  }

  public var isUserQueuePlaying: Bool {
    get { managedObject.isUserQueuePlaying }
    set { managedObject.isUserQueuePlaying = newValue }
  }

  public var contextPlaylist: Playlist {
    Playlist(library: library, managedObject: managedObject.contextPlaylist!)
  }

  public var userQueuePlaylist: Playlist {
    Playlist(library: library, managedObject: managedObject.userQueuePlaylist!)
  }

  public var songCount: Int {
    contextPlaylist.songCount + userQueuePlaylist.songCount
  }
}

// MARK: Equatable

extension SavedQueue: Equatable {
  public static func == (lhs: SavedQueue, rhs: SavedQueue) -> Bool {
    lhs.managedObject == rhs.managedObject
  }
}

// MARK: Hashable

extension SavedQueue: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(managedObject)
  }
}

// MARK: PlayableContainable

extension SavedQueue: PlayableContainable {
  public var id: String { managedObject.id?.uuidString ?? "" }
  public var subtitle: String? { nil }
  public var subsubtitle: String? { nil }

  public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if songCount == 1 {
      infoContent.append("1 Song")
    } else {
      infoContent.append("\(songCount) Songs")
    }
    return infoContent
  }

  public var playables: [AbstractPlayable] {
    contextPlaylist.playables + userQueuePlaylist.playables
  }

  public var playContextType: PlayerMode { .music }
  public var account: Account? { nil }
  public var isDownloadAvailable: Bool { true }

  @MainActor
  public func fetchFromServer(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws {
    // Saved queues are a local-only container; there is nothing to sync.
  }

  @MainActor
  public func remoteToggleFavorite(syncer: LibrarySyncer) async throws {
    throw BackendError.notSupported
  }

  @MainActor
  public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
    if !contextPlaylist.playables.isEmpty {
      return contextPlaylist.getArtworkCollection(theme: theme)
    }
    return userQueuePlaylist.getArtworkCollection(theme: theme)
  }

  public func playedViaContext() {
    lastUsedAt = Date()
  }

  public var containerIdentifier: PlayableContainerIdentifier { PlayableContainerIdentifier(
    type: .savedQueue,
    objectID: managedObject.objectID.uriRepresentation().absoluteString
  ) }
}
