//
//  SettingsTest.swift
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

class SettingsTest: XCTestCase {
  private let userKey = PersistentStorage.UserDefaultsKey.SettingsUser.rawValue
  private let appKey = PersistentStorage.UserDefaultsKey.SettingsApp.rawValue
  private var savedUserData: Data?
  private var savedAppData: Data?

  override func setUp() {
    super.setUp()
    savedUserData = UserDefaults.standard.data(forKey: userKey)
    savedAppData = UserDefaults.standard.data(forKey: appKey)
  }

  override func tearDown() {
    UserDefaults.standard.set(savedUserData, forKey: userKey)
    UserDefaults.standard.set(savedAppData, forKey: appKey)
    super.tearDown()
  }

  /// Saves `settings` without `removedKey`, as an app version without that field would have.
  private func saveWithout<T: Encodable>(
    _ removedKey: String,
    _ settings: T,
    forKey key: String
  ) throws {
    let data = try JSONEncoder().encode(settings)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertNotNil(object.removeValue(forKey: removedKey))
    UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: object), forKey: key)
  }

  private func changedUserSettings() -> UserSettings {
    var user = UserSettings()
    user.streamingMaxBitrateWifiPreference = .limit128
    user.screenLockPreventionPreference = .always
    user.isLyricsSmoothScrolling = false
    return user
  }

  private func assertChangedValuesKept(_ user: UserSettings) {
    XCTAssertEqual(user.streamingMaxBitrateWifiPreference, .limit128)
    XCTAssertEqual(user.screenLockPreventionPreference, .always)
  }

  func testUserSettingsMissingFieldKeepsSavedValues() throws {
    try saveWithout("_isLyricsSmoothScrolling", changedUserSettings(), forKey: userKey)
    var settings = AmperfySettings()

    assertChangedValuesKept(settings.user)
    XCTAssertTrue(settings.user.isLyricsSmoothScrolling, "missing field gets its default")

    settings.user.isOfflineMode = true
    let reread = AmperfySettings().user
    XCTAssertTrue(reread.isOfflineMode)
    assertChangedValuesKept(reread)
  }

  func testUserSettingsRoundTrip() {
    var settings = AmperfySettings()
    settings.user = changedUserSettings()

    let reread = AmperfySettings().user
    assertChangedValuesKept(reread)
    XCTAssertFalse(reread.isLyricsSmoothScrolling)
  }

  func testAppSettingsMissingFieldKeepsSavedValues() throws {
    var app = AppSettings()
    app.isLibrarySynced = true
    try saveWithout("_librarySyncVersion", app, forKey: appKey)

    let reread = AmperfySettings().app
    XCTAssertTrue(reread.isLibrarySynced)
    XCTAssertEqual(reread.librarySyncVersion, AppSettings().librarySyncVersion)
  }
}
