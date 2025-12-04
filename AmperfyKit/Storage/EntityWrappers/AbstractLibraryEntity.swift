//
//  AbstractLibraryEntity.swift
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
import UIKit

// MARK: - RemoteStatus

public enum RemoteStatus: Int {
  case available = 0
  case deleted = 1
}

// MARK: - AbstractLibraryEntity

public class AbstractLibraryEntity {
  private let managedObject: AbstractLibraryEntityMO

  static var typeName: String {
    String(describing: Self.self)
  }

  public init(managedObject: AbstractLibraryEntityMO) {
    self.managedObject = managedObject
  }

  public var objectID: NSManagedObjectID {
    managedObject.objectID
  }

  public var id: String {
    get { managedObject.id }
    set {
      if managedObject.id != newValue { managedObject.id = newValue }
    }
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

  public var isFavorite: Bool {
    get { managedObject.isFavorite }
    set { managedObject.isFavorite = newValue }
  }

  public var starredDate: Date? {
    get { managedObject.starredDate }
    set { if managedObject.starredDate != newValue { managedObject.starredDate = newValue } }
  }

  public var rating: Int {
    get { Int(managedObject.rating) }
    set {
      guard Int16.isValid(value: newValue), managedObject.rating != Int16(newValue), newValue >= 0,
            newValue <= 5 else { return }
      managedObject.rating = Int16(newValue)
    }
  }

  public var remoteStatus: RemoteStatus {
    get { RemoteStatus(rawValue: Int(managedObject.remoteStatus)) ?? .available }
    set {
      guard Int16.isValid(value: newValue.rawValue),
            managedObject.remoteStatus != Int16(newValue.rawValue) else { return }
      managedObject.remoteStatus = Int16(newValue.rawValue)
    }
  }

  public var playCount: Int {
    get { Int(managedObject.playCount) }
    set {
      guard Int32.isValid(value: newValue),
            managedObject.playCount != Int32(newValue) else { return }
      managedObject.playCount = Int32(newValue)
    }
  }

  public var lastTimePlayed: Date? {
    get { managedObject.lastPlayedDate }
    set { if managedObject.lastPlayedDate != newValue { managedObject.lastPlayedDate = newValue } }
  }

  public var artwork: Artwork? {
    get {
      guard let artworkMO = managedObject.artwork else { return nil }
      return Artwork(managedObject: artworkMO)
    }
    set {
      if managedObject.artwork != newValue?
        .managedObject { managedObject.artwork = newValue?.managedObject }
    }
  }

  func updateAlphabeticSectionInitial(section: String) {
    let initial = section.sectionInitial
    if managedObject.alphabeticSectionInitial != initial {
      managedObject.alphabeticSectionInitial = initial
    }
  }

  @MainActor
  public func imagePath(
    setting: ArtworkDisplayPreference
  )
    -> String? {
    artwork?.imagePath
  }

  @MainActor
  public func getDefaultArtworkType() -> ArtworkType {
    .song
  }

  public func isEqual(_ other: AbstractLibraryEntity) -> Bool {
    managedObject == other.managedObject
  }

  public func playedViaContext() {
    lastTimePlayed = Date()
    playCount += 1
  }
}

// MARK: Hashable, Equatable

extension AbstractLibraryEntity: Hashable, Equatable {
  public static func == (lhs: AbstractLibraryEntity, rhs: AbstractLibraryEntity) -> Bool {
    lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(managedObject)
  }
}
