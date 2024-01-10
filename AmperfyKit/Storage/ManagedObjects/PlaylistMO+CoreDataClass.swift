//
//  PlaylistMO+CoreDataClass.swift
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

import Foundation
import CoreData

@objc(PlaylistMO)
public final class PlaylistMO: NSManagedObject {

    static var excludeSystemPlaylistsFetchPredicate: NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersContextPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersShuffledContextPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersUserQueuePlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersPodcastPlaylist))
        ])
    }
    
    static var alphabeticSortedFetchRequest: NSFetchRequest<PlaylistMO> {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PlaylistMO.alphabeticSectionInitial), ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: Self.identifierKeyString, ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: "id", ascending: true, selector: #selector(NSString.localizedStandardCompare))
        ]
        return fetchRequest
    }
    
    static var lastPlayedDateFetchRequest: NSFetchRequest<PlaylistMO> {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PlaylistMO.lastPlayedDate), ascending: false),
            NSSortDescriptor(key: #keyPath(PlaylistMO.name), ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: #keyPath(PlaylistMO.id), ascending: true, selector: #selector(NSString.localizedStandardCompare))
        ]
        return fetchRequest
    }

    static var lastChangedDateFetchRequest: NSFetchRequest<PlaylistMO> {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PlaylistMO.changeDate), ascending: false),
            NSSortDescriptor(key: #keyPath(PlaylistMO.name), ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: #keyPath(PlaylistMO.id), ascending: true, selector: #selector(NSString.localizedStandardCompare))
        ]
        return fetchRequest
    }
    
    static var durationFetchRequest: NSFetchRequest<PlaylistMO> {
        let fetchRequest: NSFetchRequest<PlaylistMO> = PlaylistMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PlaylistMO.duration), ascending: false),
            NSSortDescriptor(key: #keyPath(PlaylistMO.songCount), ascending: false),
            NSSortDescriptor(key: #keyPath(PlaylistMO.name), ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: #keyPath(PlaylistMO.id), ascending: true, selector: #selector(NSString.localizedStandardCompare))
        ]
        return fetchRequest
    }

}

extension PlaylistMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<PlaylistMO, String?> {
        return \PlaylistMO.name
    }
    
    func passOwnership(to targetPlaylist: PlaylistMO) {
    }
    
}
