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

import Foundation
import CoreData


extension PlaylistMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistMO> {
        return NSFetchRequest<PlaylistMO>(entityName: "Playlist")
    }

    @NSManaged public var id: String
    @NSManaged public var alphabeticSectionInitial: String
    @NSManaged public var name: String?
    @NSManaged public var duration: Int16
    @NSManaged public var remoteDuration: Int16
    @NSManaged public var songCount: Int16
    @NSManaged public var items: NSSet?
    @NSManaged public var changeDate: Date?
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var playCount: Int32
    @NSManaged public var playersContextPlaylist: PlayerMO?
    @NSManaged public var playersShuffledContextPlaylist: PlayerMO?
    @NSManaged public var playersUserQueuePlaylist: PlayerMO?
    @NSManaged public var playersPodcastPlaylist: PlayerMO?

}

// MARK: Generated accessors for items
extension PlaylistMO {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: PlaylistItemMO)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: PlaylistItemMO)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}
