//
//  ArtworkMO+CoreDataProperties.swift
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

import CoreData
import Foundation

extension ArtworkMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<ArtworkMO> {
    NSFetchRequest<ArtworkMO>(entityName: "Artwork")
  }

  @NSManaged
  public var id: String
  @NSManaged
  public var imageData: Data? /// deprecated! use relFilePath instead
  @NSManaged
  public var relFilePath: String?
  @NSManaged
  public var status: Int16
  @NSManaged
  public var type: String
  @NSManaged
  public var url: String?
  @NSManaged
  public var download: DownloadMO?
  @NSManaged
  public var owners: NSSet?
}

// MARK: Generated accessors for owners

extension ArtworkMO {
  @objc(addOwnersObject:)
  @NSManaged
  public func addToOwners(_ value: AbstractLibraryEntityMO)

  @objc(removeOwnersObject:)
  @NSManaged
  public func removeFromOwners(_ value: AbstractLibraryEntityMO)

  @objc(addOwners:)
  @NSManaged
  public func addToOwners(_ values: NSSet)

  @objc(removeOwners:)
  @NSManaged
  public func removeFromOwners(_ values: NSSet)
}
