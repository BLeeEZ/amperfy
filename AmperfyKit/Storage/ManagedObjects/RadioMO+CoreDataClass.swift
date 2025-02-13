//
//  RadioMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.12.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

// MARK: - RadioMO

@objc(RadioMO)
public final class RadioMO: AbstractPlayableMO {}

// MARK: CoreDataIdentifyable

extension RadioMO: CoreDataIdentifyable {
  static var identifierKey: KeyPath<RadioMO, String?> {
    \RadioMO.title
  }

  static var excludeServerDeleteRadiosFetchPredicate: NSPredicate {
    NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(
        format: "%K == %i",
        #keyPath(RadioMO.remoteStatus),
        RemoteStatus.available.rawValue
      ),
    ])
  }

  static var alphabeticSortedFetchRequest: NSFetchRequest<RadioMO> {
    let fetchRequest: NSFetchRequest<RadioMO> = RadioMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(
        key: #keyPath(RadioMO.alphabeticSectionInitial),
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
}
