//
//  PlaylistMO+CoreDataProperties.swift
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

import CoreData
import Foundation

extension PlaylistMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<PlaylistMO> {
    NSFetchRequest<PlaylistMO>(entityName: "Playlist")
  }

  @NSManaged
  public var account: AccountMO?
  @NSManaged
  public var alphabeticSectionInitial: String
  @NSManaged
  public var changeDate: Date?
  @NSManaged
  public var duration: Int64
  @NSManaged
  public var id: String
  @NSManaged
  public var isCached: Bool
  @NSManaged
  public var lastPlayedDate: Date?
  @NSManaged
  public var name: String?
  @NSManaged
  public var playCount: Int32
  @NSManaged
  public var remoteDuration: Int64
  @NSManaged
  public var remoteSongCount: Int16
  @NSManaged
  public var songCount: Int16
  @NSManaged
  public var items: [PlaylistItemMO]
  @NSManaged
  public var playersContextPlaylist: PlayerMO?
  @NSManaged
  public var playersPodcastPlaylist: PlayerMO?
  @NSManaged
  public var playersShuffledContextPlaylist: PlayerMO?
  @NSManaged
  public var playersUserQueuePlaylist: PlayerMO?
  @NSManaged
  public var artworkItems: [PlaylistItemMO]
  @NSManaged
  public var searchHistory: SearchHistoryItemMO?

  static let relationshipKeyPathsForPrefetching = [
    #keyPath(PlaylistMO.artworkItems),
  ]
}

// MARK: Generated accessors for items

extension PlaylistMO {
  @objc(insertObject:inItemsAtIndex:)
  @NSManaged
  public func insertIntoItems(_ value: PlaylistItemMO, at idx: Int)

  @objc(removeObjectFromItemsAtIndex:)
  @NSManaged
  public func removeFromItems(at idx: Int)

  @objc(insertItems:atIndexes:)
  @NSManaged
  public func insertIntoItems(_ values: [PlaylistItemMO], at indexes: NSIndexSet)

  @objc(removeItemsAtIndexes:)
  @NSManaged
  public func removeFromItems(at indexes: NSIndexSet)

  @objc(replaceObjectInItemsAtIndex:withObject:)
  @NSManaged
  public func replaceItems(at idx: Int, with value: PlaylistItemMO)

  @objc(replaceItemsAtIndexes:withItems:)
  @NSManaged
  public func replaceItems(at indexes: NSIndexSet, with values: [PlaylistItemMO])

  @objc(addItemsObject:)
  @NSManaged
  public func addToItems(_ value: PlaylistItemMO)

  @objc(removeItemsObject:)
  @NSManaged
  public func removeFromItems(_ value: PlaylistItemMO)

  @objc(addItems:)
  @NSManaged
  public func addToItems(_ values: NSOrderedSet)

  @objc(removeItems:)
  @NSManaged
  public func removeFromItems(_ values: NSOrderedSet)
}

// MARK: Generated accessors for artworkItems

extension PlaylistMO {
  @objc(insertObject:inArtworkItemsAtIndex:)
  @NSManaged
  public func insertIntoArtworkItems(_ value: PlaylistItemMO, at idx: Int)

  @objc(removeObjectFromArtworkItemsAtIndex:)
  @NSManaged
  public func removeFromArtworkItems(at idx: Int)

  @objc(insertArtworkItems:atIndexes:)
  @NSManaged
  public func insertIntoArtworkItems(_ values: [PlaylistItemMO], at indexes: NSIndexSet)

  @objc(removeArtworkItemsAtIndexes:)
  @NSManaged
  public func removeFromArtworkItems(at indexes: NSIndexSet)

  @objc(replaceObjectInArtworkItemsAtIndex:withObject:)
  @NSManaged
  public func replaceArtworkItems(at idx: Int, with value: PlaylistItemMO)

  @objc(replaceArtworkItemsAtIndexes:withArtworkItems:)
  @NSManaged
  public func replaceArtworkItems(at indexes: NSIndexSet, with values: [PlaylistItemMO])

  @objc(addArtworkItemsObject:)
  @NSManaged
  public func addToArtworkItems(_ value: PlaylistItemMO)

  @objc(removeArtworkItemsObject:)
  @NSManaged
  public func removeFromArtworkItems(_ value: PlaylistItemMO)

  @objc(addArtworkItems:)
  @NSManaged
  public func addToArtworkItems(_ values: NSOrderedSet)

  @objc(removeArtworkItems:)
  @NSManaged
  public func removeFromArtworkItems(_ values: NSOrderedSet)
}
