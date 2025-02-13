//
//  Identifyable.swift
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

// MARK: - Identifyable

protocol Identifyable {
  var identifier: String { get }
  associatedtype ManagedObjectType where ManagedObjectType: CoreDataIdentifyable
  var managedObject: ManagedObjectType { get }
}

// MARK: - CoreDataIdentifyable

protocol CoreDataIdentifyable where Self: NSFetchRequestResult {
  static var identifierKey: KeyPath<Self, String?> { get }
  static var identifierKeyString: String { get }
  static var identifierSortedFetchRequest: NSFetchRequest<Self> { get }
  static func getIdentifierBasedSearchPredicate(searchText: String) -> NSPredicate
  static func fetchRequest() -> NSFetchRequest<Self>
}

extension CoreDataIdentifyable {
  static var identifierKeyString: String {
    NSExpression(forKeyPath: Self.identifierKey).keyPath
  }

  static func getIdentifierBasedSearchPredicate(searchText: String) -> NSPredicate {
    var predicate = NSPredicate(value: true)
    if !searchText.isEmpty {
      predicate = NSPredicate(format: "%K contains[cd] %@", Self.identifierKeyString, searchText)
    }
    return predicate
  }

  static var identifierSortedFetchRequest: NSFetchRequest<Self> {
    let fetchRequest: NSFetchRequest<Self> = Self.fetchRequest()
    fetchRequest.sortDescriptors = [
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

extension Array where Element: Identifyable {
  func filterBy(searchText: String) -> [Element] {
    let filteredArray = filter { element in
      element.identifier.isFoundBy(searchText: searchText)
    }
    return filteredArray
  }

  func sortAlphabeticallyAscending() -> [Element] {
    sorted {
      $0.identifier.localizedStandardCompare($1.identifier) == ComparisonResult.orderedAscending
    }
  }

  func sortAlphabeticallyDescending() -> [Element] {
    sorted {
      $0.identifier.localizedStandardCompare($1.identifier) == ComparisonResult.orderedDescending
    }
  }
}
