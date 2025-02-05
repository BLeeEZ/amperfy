//
//  MusicFolder.swift
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

import Foundation

public class MusicFolder {
    
    public static var typeName: String {
        return String(describing: Self.self)
    }
    
    public let managedObject: MusicFolderMO
    
    public init(managedObject: MusicFolderMO) {
        self.managedObject = managedObject
    }
    
    public var id: String {
        get { return managedObject.id }
        set {
            if managedObject.id != newValue { managedObject.id = newValue }
        }
    }
    public var name: String {
        get { return managedObject.name }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    public var isCached: Bool {
        get { return managedObject.isCached }
        set {
            if managedObject.isCached != newValue {
                managedObject.isCached = newValue
            }
        }
    }
    public var directories: [Directory] {
        return managedObject.directories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
    }
    public var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }

}

extension MusicFolder: Hashable, Equatable {
    public static func == (lhs: MusicFolder, rhs: MusicFolder) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
