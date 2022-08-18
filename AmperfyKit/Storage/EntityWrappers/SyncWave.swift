//
//  SyncWave.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 02.01.20.
//  Copyright (c) 2020 Maximilian Bauer. All rights reserved.
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

public enum SyncState: Int {
    case Artists
    case Albums
    case Songs
    case Done
}

public enum SyncType: Int {
    case newEntries = 0
    case versionResync = 1
}

public class SyncWave: NSObject {
    
    public let managedObject: SyncWaveMO

    public init(managedObject: SyncWaveMO) {
        self.managedObject = managedObject
    }
    
    public var id: Int {
        get { return Int(managedObject.id) }
        set { managedObject.id = Int16(newValue) }
    }
    public var syncState: SyncState {
        get {
            return SyncState(rawValue: Int(managedObject.syncState)) ?? .Artists
        }
        set {
            syncIndexToContinue = ""
            managedObject.syncState = Int16(newValue.rawValue)
        }
    }
    public var syncType: SyncType {
        get {
            return SyncType(rawValue: Int(managedObject.syncType)) ?? .newEntries
        }
        set {
            syncIndexToContinue = ""
            managedObject.syncType = Int16(newValue.rawValue)
        }
    }
    public var syncIndexToContinue: String {
        get { return managedObject.syncIndexToContinue }
        set { managedObject.syncIndexToContinue = newValue }
    }
    public var version: LibrarySyncVersion {
        get { return LibrarySyncVersion(rawValue: Int(managedObject.version)) ?? .defaultValue }
        set { managedObject.version = Int16(newValue.rawValue) }
    }
    public var isInitialWave: Bool {
        return managedObject.id == 0
    }
    public var isDone: Bool {
        return syncState == .Done
    }
    
    public var libraryChangeDates: LibraryChangeDates {
        let temp = LibraryChangeDates()
        temp.dateOfLastUpdate = managedObject.dateOfLastUpdate ?? Date()
        temp.dateOfLastAdd = managedObject.dateOfLastAdd ?? Date()
        temp.dateOfLastClean = managedObject.dateOfLastClean ?? Date()
        return temp
    }

    public func setMetaData(fromLibraryChangeDates: LibraryChangeDates) {
        managedObject.dateOfLastUpdate = fromLibraryChangeDates.dateOfLastUpdate
        managedObject.dateOfLastAdd = fromLibraryChangeDates.dateOfLastAdd
        managedObject.dateOfLastClean = fromLibraryChangeDates.dateOfLastClean
    }
    
    public var songs: [Song] {
        var returnSongs = [Song]()
        guard let songsMOSet = managedObject.songs, let songsMOArray = songsMOSet.array as? [SongMO] else { return returnSongs }
        for song in songsMOArray {
            returnSongs.append(Song(managedObject: song))
        }
        return returnSongs
    }
    
    public var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SyncWave else { return false }
        return managedObject == object.managedObject
    }

}
