//
//  AbstractPlayableMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

extension AbstractPlayableMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<AbstractPlayableMO> {
    NSFetchRequest<AbstractPlayableMO>(entityName: "AbstractPlayable")
  }

  @NSManaged
  public var bitrate: Int32
  @NSManaged
  public var contentType: String?
  @NSManaged
  public var contentTypeTranscoded: String?
  @NSManaged
  public var disk: String?
  @NSManaged
  public var relFilePath: String?
  @NSManaged
  public var combinedDuration: Int16
  @NSManaged
  public var playDuration: Int16
  @NSManaged
  public var playProgress: Int16
  @NSManaged
  public var remoteDuration: Int16
  @NSManaged
  public var size: Int32
  @NSManaged
  public var title: String?
  @NSManaged
  public var track: Int16
  @NSManaged
  public var url: String?
  @NSManaged
  public var year: Int16
  @NSManaged
  public var replayGainTrackGain: Float
  @NSManaged
  public var replayGainTrackPeak: Float
  @NSManaged
  public var replayGainAlbumGain: Float
  @NSManaged
  public var replayGainAlbumPeak: Float
  @NSManaged
  public var download: DownloadMO?
  @NSManaged
  public var embeddedArtwork: EmbeddedArtworkMO?
  @NSManaged
  public var playlistItems: [PlaylistItemMO]
  @NSManaged
  public var scrobbleEntries: NSOrderedSet?
}

// MARK: Generated accessors for playlistItems

extension AbstractPlayableMO {
  @objc(insertObject:inPlaylistItemsAtIndex:)
  @NSManaged
  public func insertIntoPlaylistItems(_ value: PlaylistItemMO, at idx: Int)

  @objc(removeObjectFromPlaylistItemsAtIndex:)
  @NSManaged
  public func removeFromPlaylistItems(at idx: Int)

  @objc(insertPlaylistItems:atIndexes:)
  @NSManaged
  public func insertIntoPlaylistItems(_ values: [PlaylistItemMO], at indexes: NSIndexSet)

  @objc(removePlaylistItemsAtIndexes:)
  @NSManaged
  public func removeFromPlaylistItems(at indexes: NSIndexSet)

  @objc(replaceObjectInPlaylistItemsAtIndex:withObject:)
  @NSManaged
  public func replacePlaylistItems(at idx: Int, with value: PlaylistItemMO)

  @objc(replacePlaylistItemsAtIndexes:withPlaylistItems:)
  @NSManaged
  public func replacePlaylistItems(at indexes: NSIndexSet, with values: [PlaylistItemMO])

  @objc(addPlaylistItemsObject:)
  @NSManaged
  public func addToPlaylistItems(_ value: PlaylistItemMO)

  @objc(removePlaylistItemsObject:)
  @NSManaged
  public func removeFromPlaylistItems(_ value: PlaylistItemMO)

  @objc(addPlaylistItems:)
  @NSManaged
  public func addToPlaylistItems(_ values: NSOrderedSet)

  @objc(removePlaylistItems:)
  @NSManaged
  public func removeFromPlaylistItems(_ values: NSOrderedSet)
}

// MARK: Generated accessors for scrobbleEntries

extension AbstractPlayableMO {
  @objc(insertObject:inScrobbleEntriesAtIndex:)
  @NSManaged
  public func insertIntoScrobbleEntries(_ value: ScrobbleEntryMO, at idx: Int)

  @objc(removeObjectFromScrobbleEntriesAtIndex:)
  @NSManaged
  public func removeFromScrobbleEntries(at idx: Int)

  @objc(insertScrobbleEntries:atIndexes:)
  @NSManaged
  public func insertIntoScrobbleEntries(
    _ values: [ScrobbleEntryMO],
    at indexes: NSIndexSet
  )

  @objc(removeScrobbleEntriesAtIndexes:)
  @NSManaged
  public func removeFromScrobbleEntries(at indexes: NSIndexSet)

  @objc(replaceObjectInScrobbleEntriesAtIndex:withObject:)
  @NSManaged
  public func replaceScrobbleEntries(at idx: Int, with value: ScrobbleEntryMO)

  @objc(replaceScrobbleEntriesAtIndexes:withScrobbleEntries:)
  @NSManaged
  public func replaceScrobbleEntries(
    at indexes: NSIndexSet,
    with values: [ScrobbleEntryMO]
  )

  @objc(addScrobbleEntriesObject:)
  @NSManaged
  public func addToScrobbleEntries(_ value: ScrobbleEntryMO)

  @objc(removeScrobbleEntriesObject:)
  @NSManaged
  public func removeFromScrobbleEntries(_ value: ScrobbleEntryMO)

  @objc(addScrobbleEntries:)
  @NSManaged
  public func addToScrobbleEntries(_ values: NSOrderedSet)

  @objc(removeScrobbleEntries:)
  @NSManaged
  public func removeFromScrobbleEntries(_ values: NSOrderedSet)
}
