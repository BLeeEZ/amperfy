//
//  PlaylistItem.swift
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

public class PlaylistItem: NSObject {
  public let managedObject: PlaylistItemMO
  private let library: LibraryStorage

  public init(library: LibraryStorage, managedObject: PlaylistItemMO) {
    self.library = library
    self.managedObject = managedObject
  }

  public var objectID: NSManagedObjectID {
    managedObject.objectID
  }

  public var account: Account? {
    get {
      guard let accountMO = managedObject.account else { return nil }
      return Account(managedObject: accountMO)
    }
    set {
      if managedObject.account != newValue?
        .managedObject { managedObject.account = newValue?.managedObject }
    }
  }

  public var order: Int {
    get { Int(managedObject.order) }
    set {
      guard Int32.isValid(value: newValue), managedObject.order != Int32(newValue) else { return }
      managedObject.order = Int32(newValue)
    }
  }

  public var playable: AbstractPlayable {
    get { AbstractPlayable(managedObject: managedObject.playable) }
    set { managedObject.playable = newValue.playableManagedObject }
  }

  public var playlist: Playlist {
    get { Playlist(library: library, managedObject: managedObject.playlist) }
    set { managedObject.playlist = newValue.managedObject }
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let object = object as? PlaylistItem else { return false }
    return managedObject == object.managedObject
  }
}
