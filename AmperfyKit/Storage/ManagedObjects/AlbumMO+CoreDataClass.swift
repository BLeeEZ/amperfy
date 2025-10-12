//
//  AlbumMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 31.12.19.
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

// MARK: - AlbumMO

@objc(AlbumMO)
public final class AlbumMO: AbstractLibraryEntityMO {
  override public func willSave() {
    super.willSave()
    if hasChangedSongs {
      updateSongCount()
    }
  }

  fileprivate var hasChangedSongs: Bool {
    changedValues().keys.contains(#keyPath(songs))
  }

  fileprivate func updateSongCount() {
    guard Int16(clamping: songs?.count ?? 0) != songCount else { return }
    songCount = Int16(clamping: songs?.count ?? 0)
  }

  static func getFetchPredicateForAlbumsWhoseSongsHave(artist: Artist) -> NSPredicate {
    NSPredicate(
      format: "SUBQUERY(songs, $song, $song.artist == %@) .@count > 0",
      artist.managedObject.objectID
    )
  }

  static var alphabeticSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(AlbumMO.alphabeticSectionInitial),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: "id",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var releaseYearSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.year), ascending: true),
      NSSortDescriptor(key: #keyPath(AlbumMO.name), ascending: true),
    ]
    return fetchRequest
  }

  static var ratingSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.rating), ascending: false),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: #keyPath(AlbumMO.id),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var newestSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.newestIndex), ascending: true),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: #keyPath(AlbumMO.id),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var recentSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.recentIndex), ascending: true),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: #keyPath(AlbumMO.id),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var artistNameSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(AlbumMO.artist.alphabeticSectionInitial),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: #keyPath(AlbumMO.artist.name),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: #keyPath(AlbumMO.alphabeticSectionInitial),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: "id",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var durationSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.duration), ascending: true),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: "id",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var yearSortedFetchRequest: NSFetchRequest<AlbumMO> {
    let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(AlbumMO.year), ascending: false),
      NSSortDescriptor(
        key: Self.identifierKeyString,
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
      NSSortDescriptor(
        key: "id",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }
}

// MARK: CoreDataIdentifyable

extension AlbumMO: CoreDataIdentifyable {
  static var identifierKey: KeyPath<AlbumMO, String?> {
    \AlbumMO.name
  }

  func passOwnership(to targetAlbum: AlbumMO) {
    let songsCopy = songs?.compactMap { $0 as? SongMO }
    songsCopy?.forEach {
      $0.album = targetAlbum
    }
  }
}
