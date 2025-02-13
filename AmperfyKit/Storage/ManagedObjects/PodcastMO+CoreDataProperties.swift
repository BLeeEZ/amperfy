//
//  PodcastMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.06.21.
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

extension PodcastMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<PodcastMO> {
    NSFetchRequest<PodcastMO>(entityName: "Podcast")
  }

  @NSManaged
  public var depiction: String?
  @NSManaged
  public var episodeCount: Int16
  @NSManaged
  public var episodes: NSOrderedSet?
  @NSManaged
  public var title: String?
  @NSManaged
  public var isCached: Bool

  static let relationshipKeyPathsForPrefetching = [
    #keyPath(PodcastMO.artwork),
  ]
}

// MARK: Generated accessors for episodes

extension PodcastMO {
  @objc(insertObject:inEpisodesAtIndex:)
  @NSManaged
  public func insertIntoEpisodes(_ value: PodcastEpisodeMO, at idx: Int)

  @objc(removeObjectFromEpisodesAtIndex:)
  @NSManaged
  public func removeFromEpisodes(at idx: Int)

  @objc(insertEpisodes:atIndexes:)
  @NSManaged
  public func insertIntoEpisodes(_ values: [PodcastEpisodeMO], at indexes: NSIndexSet)

  @objc(removeEpisodesAtIndexes:)
  @NSManaged
  public func removeFromEpisodes(at indexes: NSIndexSet)

  @objc(replaceObjectInEpisodesAtIndex:withObject:)
  @NSManaged
  public func replaceEpisodes(at idx: Int, with value: PodcastEpisodeMO)

  @objc(replaceEpisodesAtIndexes:withEpisodes:)
  @NSManaged
  public func replaceEpisodes(at indexes: NSIndexSet, with values: [PodcastEpisodeMO])

  @objc(addEpisodesObject:)
  @NSManaged
  public func addToEpisodes(_ value: PodcastEpisodeMO)

  @objc(removeEpisodesObject:)
  @NSManaged
  public func removeFromEpisodes(_ value: PodcastEpisodeMO)

  @objc(addEpisodes:)
  @NSManaged
  public func addToEpisodes(_ values: NSOrderedSet)

  @objc(removeEpisodes:)
  @NSManaged
  public func removeFromEpisodes(_ values: NSOrderedSet)
}
