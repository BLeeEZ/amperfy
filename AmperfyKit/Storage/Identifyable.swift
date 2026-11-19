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
      predicate = .searchContains(key: Self.identifierKeyString, searchText: searchText)
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

// MARK: - NSPredicate

extension NSPredicate {
  /// `key contains[cd] searchText`, also finding the text with its apostrophes all ', all ’, or
  /// smart quoted (’ after a letter or digit, ‘ elsewhere), as tags usually write them (#787).
  static func searchContains(key: String, searchText: String) -> NSPredicate {
    func keyContains(_ text: String) -> NSPredicate {
      NSPredicate(format: "%K contains[cd] %@", key, text)
    }
    guard searchText.contains(where: \.isSearchApostrophe) else {
      return keyContains(searchText)
    }
    let smartQuoted = zip([" "] + searchText, searchText).map { previous, character -> Character in
      guard character.isSearchApostrophe else { return character }
      return previous.isLetter || previous.isNumber ? "\u{2019}" : "\u{2018}"
    }
    var variants = [String]()
    for variant in [
      searchText,
      String(searchText.map { $0.isSearchApostrophe ? "'" : $0 }),
      String(searchText.map { $0.isSearchApostrophe ? "\u{2019}" : $0 }),
      String(smartQuoted),
    ] where !variants.contains(variant) {
      variants.append(variant)
    }
    let anyVariant = NSCompoundPredicate(orPredicateWithSubpredicates: variants.map(keyContains))
    // Every variant contains the longest part between apostrophes. SQLite checks it first, so it
    // runs the variants only on the rows that contain it. A single character filters too few rows
    // to pay off.
    let parts = searchText.split(whereSeparator: \.isSearchApostrophe)
    guard let longestPart = parts.max(by: { $0.count < $1.count }), longestPart.count > 1 else {
      return anyVariant
    }
    return NSCompoundPredicate(andPredicateWithSubpredicates: [
      keyContains(String(longestPart)),
      anyVariant,
    ])
  }
}
