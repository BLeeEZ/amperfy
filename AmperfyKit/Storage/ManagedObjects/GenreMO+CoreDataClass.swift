//
//  GenreMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.04.21.
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

import CoreData
import Foundation

// MARK: - GenreMO

@objc(GenreMO)
public final class GenreMO: AbstractLibraryEntityMO {
  override public func willSave() {
    super.willSave()
    if hasChangedSongs {
      updateSongCount()
    }
    if hasChangedAlbums {
      updateAlbumCount()
    }
    if hasChangedArtists {
      updateArtistCount()
    }
  }

  fileprivate var hasChangedSongs: Bool {
    changedValues().keys.contains(#keyPath(songs))
  }

  fileprivate func updateSongCount() {
    guard Int16(clamping: songs?.count ?? 0) != songCount else { return }
    songCount = Int16(clamping: songs?.count ?? 0)
  }

  fileprivate var hasChangedAlbums: Bool {
    changedValues().keys.contains(#keyPath(albums))
  }

  fileprivate func updateAlbumCount() {
    guard Int16(clamping: albums?.count ?? 0) != albumCount else { return }
    albumCount = Int16(clamping: albums?.count ?? 0)
  }

  fileprivate var hasChangedArtists: Bool {
    changedValues().keys.contains(#keyPath(artists))
  }

  fileprivate func updateArtistCount() {
    guard Int16(clamping: artists?.count ?? 0) != artistCount else { return }
    artistCount = Int16(clamping: artists?.count ?? 0)
  }
}

// MARK: CoreDataIdentifyable

extension GenreMO: CoreDataIdentifyable {
  static var identifierKey: KeyPath<GenreMO, String?> {
    \GenreMO.name
  }

  static var alphabeticSortedFetchRequest: NSFetchRequest<GenreMO> {
    let fetchRequest: NSFetchRequest<GenreMO> = GenreMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(GenreMO.alphabeticSectionInitial),
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

  func passOwnership(to targetGenre: GenreMO) {
    let artistsCopy = artists?.compactMap { $0 as? ArtistMO }
    artistsCopy?.forEach {
      $0.genre = targetGenre
    }

    let albumsCopy = albums?.compactMap { $0 as? AlbumMO }
    albumsCopy?.forEach {
      $0.genre = targetGenre
    }

    let songsCopy = songs?.compactMap { $0 as? SongMO }
    songsCopy?.forEach {
      $0.genre = targetGenre
    }
  }
}
