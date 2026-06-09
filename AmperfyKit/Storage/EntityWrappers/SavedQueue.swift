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

  public init(managedObject: SavedQueueMO) {
    self.managedObject = managedObject
  }

  public var id: UUID {
    managedObject.id ?? UUID()
  }

  public var name: String {
    get { managedObject.name ?? "" }
    set { managedObject.name = newValue }
  }

  public var createdAt: Date {
    managedObject.createdAt ?? Date.distantPast
  }

  public var playerMode: PlayerMode {
    PlayerMode(rawValue: managedObject.playerMode) ?? .music
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

  public var songCount: Int {
    get { Int(managedObject.songCount) }
    set { managedObject.songCount = Int32(newValue) }
  }

  public var contextSongIds: [String] {
    get { Self.decodeIds(managedObject.contextSongIds) }
    set { managedObject.contextSongIds = Self.encodeIds(newValue) }
  }

  public var userQueueSongIds: [String] {
    get { Self.decodeIds(managedObject.userQueueSongIds) }
    set { managedObject.userQueueSongIds = Self.encodeIds(newValue) }
  }

  private static func encodeIds(_ ids: [String]) -> Data {
    (try? JSONEncoder().encode(ids)) ?? Data()
  }

  private static func decodeIds(_ data: Data?) -> [String] {
    guard let data, !data.isEmpty else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
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
