//
//  EmbeddedArtwork.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 07.11.21.
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
import UIKit

public class EmbeddedArtwork: NSObject {
  public let managedObject: EmbeddedArtworkMO
  private let fileManager = CacheFileManager.shared

  public init(managedObject: EmbeddedArtworkMO) {
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

  public var imagePath: String? {
    if let relFilePath = relFilePath,
       let absolutePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
      return absolutePath.path
    } else {
      return nil
    }
  }

  public var relFilePath: URL? {
    get {
      if let relFilePathString = managedObject.relFilePath {
        return URL(string: relFilePathString)
      }
      return nil
    }
    set {
      managedObject.relFilePath = newValue?.path
    }
  }

  public var owner: AbstractPlayable? {
    get {
      guard let ownerMO = managedObject.owner else { return nil }
      return AbstractPlayable(managedObject: ownerMO)
    }
    set {
      if managedObject.owner != newValue?
        .playableManagedObject { managedObject.owner = newValue?.playableManagedObject }
    }
  }
}
