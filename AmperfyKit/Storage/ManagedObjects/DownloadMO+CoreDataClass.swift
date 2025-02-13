//
//  DownloadMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
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

// MARK: - DownloadMO

@objc(DownloadMO)
public class DownloadMO: NSManagedObject {}

extension DownloadMO {
  static var creationDateSortedFetchRequest: NSFetchRequest<DownloadMO> {
    let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: #keyPath(DownloadMO.creationDate), ascending: true),
      NSSortDescriptor(
        key: #keyPath(DownloadMO.id),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
      ),
    ]
    return fetchRequest
  }

  static var onlyPlayablesPredicate: NSPredicate {
    NSPredicate(format: "%K != nil", #keyPath(DownloadMO.playable))
  }

  static var onlyArtworksPredicate: NSPredicate {
    NSPredicate(format: "%K != nil", #keyPath(DownloadMO.artwork))
  }
}
