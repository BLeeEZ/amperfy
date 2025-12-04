//
//  PlaylistItemMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 30.12.19.
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

extension PlaylistItemMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<PlaylistItemMO> {
    NSFetchRequest<PlaylistItemMO>(entityName: "PlaylistItem")
  }

  @NSManaged
  public var account: AccountMO?
  @NSManaged
  public var order: Int32
  @NSManaged
  public var playable: AbstractPlayableMO
  @NSManaged
  public var playlist: PlaylistMO
  @NSManaged
  public var playlistArtworkItem: PlaylistMO?

  static let relationshipKeyPathsForPrefetching = [
    #keyPath(PlaylistItemMO.playlistArtworkItem),
    #keyPath(PlaylistItemMO.playable),
    #keyPath(PlaylistItemMO.playable.artwork),
    #keyPath(PlaylistItemMO.playable.embeddedArtwork),
  ]
}
