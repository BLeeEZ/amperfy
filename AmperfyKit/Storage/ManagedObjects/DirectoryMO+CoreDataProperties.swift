//
//  DirectoryMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.05.21.
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

extension DirectoryMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<DirectoryMO> {
    NSFetchRequest<DirectoryMO>(entityName: "Directory")
  }

  @NSManaged
  public var name: String?
  @NSManaged
  public var parent: DirectoryMO?
  @NSManaged
  public var subdirectoryCount: Int16
  @NSManaged
  public var songCount: Int16
  @NSManaged
  public var songs: NSOrderedSet?
  @NSManaged
  public var subdirectories: NSOrderedSet?
  @NSManaged
  public var musicFolder: MusicFolderMO?
  @NSManaged
  public var isCached: Bool

  static let relationshipKeyPathsForPrefetching = [String]()
}

// MARK: Generated accessors for songs

extension DirectoryMO {
  @objc(insertObject:inSongsAtIndex:)
  @NSManaged
  public func insertIntoSongs(_ value: SongMO, at idx: Int)

  @objc(removeObjectFromSongsAtIndex:)
  @NSManaged
  public func removeFromSongs(at idx: Int)

  @objc(insertSongs:atIndexes:)
  @NSManaged
  public func insertIntoSongs(_ values: [SongMO], at indexes: NSIndexSet)

  @objc(removeSongsAtIndexes:)
  @NSManaged
  public func removeFromSongs(at indexes: NSIndexSet)

  @objc(replaceObjectInSongsAtIndex:withObject:)
  @NSManaged
  public func replaceSongs(at idx: Int, with value: SongMO)

  @objc(replaceSongsAtIndexes:withSongs:)
  @NSManaged
  public func replaceSongs(at indexes: NSIndexSet, with values: [SongMO])

  @objc(addSongsObject:)
  @NSManaged
  public func addToSongs(_ value: SongMO)

  @objc(removeSongsObject:)
  @NSManaged
  public func removeFromSongs(_ value: SongMO)

  @objc(addSongs:)
  @NSManaged
  public func addToSongs(_ values: NSOrderedSet)

  @objc(removeSongs:)
  @NSManaged
  public func removeFromSongs(_ values: NSOrderedSet)
}

// MARK: Generated accessors for subdirectories

extension DirectoryMO {
  @objc(insertObject:inSubdirectoriesAtIndex:)
  @NSManaged
  public func insertIntoSubdirectories(_ value: DirectoryMO, at idx: Int)

  @objc(removeObjectFromSubdirectoriesAtIndex:)
  @NSManaged
  public func removeFromSubdirectories(at idx: Int)

  @objc(insertSubdirectories:atIndexes:)
  @NSManaged
  public func insertIntoSubdirectories(_ values: [DirectoryMO], at indexes: NSIndexSet)

  @objc(removeSubdirectoriesAtIndexes:)
  @NSManaged
  public func removeFromSubdirectories(at indexes: NSIndexSet)

  @objc(replaceObjectInSubdirectoriesAtIndex:withObject:)
  @NSManaged
  public func replaceSubdirectories(at idx: Int, with value: DirectoryMO)

  @objc(replaceSubdirectoriesAtIndexes:withSubdirectories:)
  @NSManaged
  public func replaceSubdirectories(at indexes: NSIndexSet, with values: [DirectoryMO])

  @objc(addSubdirectoriesObject:)
  @NSManaged
  public func addToSubdirectories(_ value: DirectoryMO)

  @objc(removeSubdirectoriesObject:)
  @NSManaged
  public func removeFromSubdirectories(_ value: DirectoryMO)

  @objc(addSubdirectories:)
  @NSManaged
  public func addToSubdirectories(_ values: NSOrderedSet)

  @objc(removeSubdirectories:)
  @NSManaged
  public func removeFromSubdirectories(_ values: NSOrderedSet)
}
