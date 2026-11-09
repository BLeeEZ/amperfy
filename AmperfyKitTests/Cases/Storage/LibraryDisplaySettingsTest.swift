//
//  LibraryDisplaySettingsTest.swift
//  AmperfyKitTests
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

@testable import AmperfyKit
import XCTest

@MainActor
class LibraryDisplaySettingsTest: XCTestCase {
  private let cachedTypes: [LibraryDisplayType] = [.cachedArtists, .cachedAlbums, .cachedSongs]

  /// Decodes settings as an app version without the cached types would have stored them.
  private func decodeStoredSettings(
    inUse: [LibraryDisplayType],
    notUsed: [LibraryDisplayType]
  ) throws
    -> LibraryDisplaySettings {
    let stored: [String: Any] = [
      "combined": [inUse.map { $0.rawValue }, notUsed.map { $0.rawValue }],
      "order": (inUse + notUsed).map { $0.rawValue },
    ]
    let data = try JSONSerialization.data(withJSONObject: stored)
    return try JSONDecoder().decode(LibraryDisplaySettings.self, from: data)
  }

  func testCachedTypesAreNotUsedInStoredSettings() throws {
    let inUse: [LibraryDisplayType] = [.artists, .albums, .songs]
    let notUsed = LibraryDisplayType.allCases.filter {
      !inUse.contains($0) && !cachedTypes.contains($0)
    }
    let settings = try decodeStoredSettings(inUse: inUse, notUsed: notUsed)
    XCTAssertEqual(settings.inUse, inUse)
    XCTAssertEqual(settings.notUsed, notUsed + cachedTypes)
  }

  func testCachedTypesInUseAreKeptAfterEncoding() throws {
    let inUse: [LibraryDisplayType] = [.songs] + cachedTypes
    let data = try JSONEncoder().encode(LibraryDisplaySettings(inUse: inUse))
    let decoded = try JSONDecoder().decode(LibraryDisplaySettings.self, from: data)
    XCTAssertEqual(decoded.inUse, inUse)
  }

  func testCachedTypesAreNotVisibleByDefault() {
    for type in cachedTypes {
      XCTAssertFalse(LibraryDisplaySettings.defaultSettings.isVisible(libraryType: type))
    }
  }

  func testCreateByDisplayNameFindsEveryType() {
    for type in LibraryDisplayType.allCases {
      XCTAssertEqual(LibraryDisplayType.createByDisplayName(name: type.displayName), type)
    }
  }
}
