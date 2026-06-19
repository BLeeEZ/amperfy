//
//  SavedQueueMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Amperfy Contributors on 08.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

public import Foundation
public import CoreData

extension SavedQueueMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<SavedQueueMO> {
    NSFetchRequest<SavedQueueMO>(entityName: "SavedQueue")
  }

  @NSManaged
  public var id: UUID?
  @NSManaged
  public var name: String?
  @NSManaged
  public var lastUsedAt: Date?
  @NSManaged
  public var playerMode: Int16
  @NSManaged
  public var currentIndex: Int32
  @NSManaged
  public var isShuffle: Bool
  @NSManaged
  public var repeatMode: Int16
  @NSManaged
  public var isUserQueuePlaying: Bool
  @NSManaged
  public var songCount: Int32
  @NSManaged
  public var contextSongIds: Data?
  @NSManaged
  public var userQueueSongIds: Data?
  @NSManaged
  public var toAccount: AccountMO?
}

// MARK: - SavedQueueMO + Identifiable

extension SavedQueueMO: Identifiable {}
