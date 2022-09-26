//
//  Directory.swift
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

public class Directory: AbstractLibraryEntity {
    
    public let managedObject: DirectoryMO
    
    public init(managedObject: DirectoryMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var name: String {
        get { return managedObject.name ?? "" }
        set {
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }
    public var subdirectories: [Directory] {
        return managedObject.subdirectories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
    }

}

extension Directory: Hashable, Equatable {
    public static func == (lhs: Directory, rhs: Directory) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
