//
//  DirectoryMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.05.21.
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

// MARK: - DirectoryMO

@objc(DirectoryMO)
public final class DirectoryMO: AbstractLibraryEntityMO {
  override public func willSave() {
    super.willSave()
    if hasChangedSongs {
      updateSongCount()
    }
    if hasChangedSubdirectories {
      updateSubdirectoryCount()
    }
  }

  fileprivate var hasChangedSongs: Bool {
    changedValues().keys.contains(#keyPath(songs))
  }

  fileprivate func updateSongCount() {
    guard Int16(clamping: songs?.count ?? 0) != songCount else { return }
    songCount = Int16(clamping: songs?.count ?? 0)
  }

  fileprivate var hasChangedSubdirectories: Bool {
    changedValues().keys.contains(#keyPath(subdirectories))
  }

  fileprivate func updateSubdirectoryCount() {
    guard Int16(clamping: subdirectories?.count ?? 0) != subdirectoryCount else { return }
    subdirectoryCount = Int16(clamping: subdirectories?.count ?? 0)
  }

  static var alphabeticSortedFetchRequest: NSFetchRequest<DirectoryMO> {
    let fetchRequest: NSFetchRequest<DirectoryMO> = DirectoryMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(DirectoryMO.alphabeticSectionInitial),
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

  static func getSearchPredicate(searchText: String) -> NSPredicate {
    var predicate = NSPredicate(value: true)
    if !searchText.isEmpty {
      predicate = NSPredicate(format: "%K contains[cd] %@", #keyPath(DirectoryMO.name), searchText)
    }
    return predicate
  }
}

// MARK: CoreDataIdentifyable

extension DirectoryMO: CoreDataIdentifyable {
  static var identifierKey: KeyPath<DirectoryMO, String?> {
    \DirectoryMO.name
  }
}
