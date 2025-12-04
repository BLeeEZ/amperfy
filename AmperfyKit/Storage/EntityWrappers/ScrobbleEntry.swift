//
//  ScrobbleEntry.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.03.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

public class ScrobbleEntry: NSObject {
  public let managedObject: ScrobbleEntryMO

  public init(managedObject: ScrobbleEntryMO) {
    self.managedObject = managedObject
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

  public var date: Date? {
    get { managedObject.date }
    set { managedObject.date = newValue }
  }

  public var isUploaded: Bool {
    get { managedObject.isUploaded }
    set { managedObject.isUploaded = newValue }
  }

  public var playable: AbstractPlayable? {
    get {
      guard let songMO = managedObject.playable else { return nil }
      return AbstractPlayable(managedObject: songMO)
    }
    set { managedObject.playable = newValue?.playableManagedObject }
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let object = object as? ScrobbleEntry else { return false }
    return managedObject == object.managedObject
  }
}
