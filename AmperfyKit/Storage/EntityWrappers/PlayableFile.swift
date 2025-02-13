//
//  PlayableFile.swift
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

import CoreData
import Foundation

public class PlayableFile: NSObject {
  public let managedObject: PlayableFileMO

  public init(managedObject: PlayableFileMO) {
    self.managedObject = managedObject
  }

  public var info: AbstractPlayable? {
    get {
      guard let songMO = managedObject.info else { return nil }
      return AbstractPlayable(managedObject: songMO)
    }
    set {
      guard let playable = newValue else {
        managedObject.info = nil
        return
      }
      managedObject.info = playable.playableManagedObject
    }
  }

  public var data: Data? {
    get {
      managedObject.data
    }
    set {
      managedObject.data = newValue
    }
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let object = object as? PlayableFile else { return false }
    return managedObject == object.managedObject
  }
}
