//
//  AbstractLibraryEntityMO+CoreDataProperties.swift
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

extension AbstractLibraryEntityMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<AbstractLibraryEntityMO> {
    NSFetchRequest<AbstractLibraryEntityMO>(entityName: "AbstractLibraryEntity")
  }

  @NSManaged
  public var id: String
  @NSManaged
  public var account: AccountMO?
  @NSManaged
  public var alphabeticSectionInitial: String
  @NSManaged
  public var isFavorite: Bool
  @NSManaged
  public var starredDate: Date?
  @NSManaged
  public var rating: Int16
  @NSManaged
  public var remoteStatus: Int16
  @NSManaged
  public var playCount: Int32
  @NSManaged
  public var lastPlayedDate: Date?
  @NSManaged
  public var artwork: ArtworkMO?
  @NSManaged
  public var searchHistory: SearchHistoryItemMO?
}
