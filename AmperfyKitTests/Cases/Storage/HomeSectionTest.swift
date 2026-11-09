//
//  HomeSectionTest.swift
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

class HomeSectionTest: XCTestCase {
  private let cachedSections: [HomeSection] = [.cachedArtists, .cachedAlbums, .cachedSongs]

  func testCachedSectionsAreAddedAtTheEndOfStoredOrder() {
    let storedOrder = Array(HomeSection.allCases.filter { !cachedSections.contains($0) }.reversed())
    var accountSetting = AccountSetting()
    accountSetting.homeSectionOrder = storedOrder
    XCTAssertEqual(accountSetting.homeSectionOrder, storedOrder + cachedSections)
  }

  func testCachedSectionsAreNotVisibleByDefault() {
    for section in cachedSections {
      XCTAssertFalse(HomeSection.defaultValue.contains(section))
    }
  }

  func testOnlyCachedSectionsAreCachedAndRefreshable() {
    XCTAssertEqual(HomeSection.allCases.filter { $0.isCachedSection }, cachedSections)
    XCTAssertTrue(cachedSections.allSatisfy { $0.isRandomSection })
  }

  func testCreateFromTitleFindsEverySection() {
    for section in HomeSection.allCases {
      XCTAssertEqual(HomeSection.create(fromTitle: section.title), section)
    }
  }
}
