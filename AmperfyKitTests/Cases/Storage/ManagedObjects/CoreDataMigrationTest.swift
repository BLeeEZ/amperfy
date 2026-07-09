//
//  CoreDataMigrationTest.swift
//  AmperfyKitTests
//
//  Created by Amperfy Contributors on 10.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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
import CoreData
import XCTest

@MainActor
class CoreDataMigrationTest: XCTestCase {
  var storeURL: URL!

  override func setUp() async throws {
    storeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("MigrationTest-\(UUID().uuidString).sqlite")
  }

  override func tearDown() {
    if FileManager.default.fileExists(atPath: storeURL.path) {
      NSPersistentStoreCoordinator.destroyStore(at: storeURL)
    }
  }

  /// Creates a store with the given (old) model version and seeds one account
  /// so data survival can be verified after migration.
  private func createStore(version: CoreDataMigrationVersion) throws {
    let model = NSManagedObjectModel.managedObjectModel(forResource: version.rawValue)
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let store = coordinator.addPersistentStore(at: storeURL, options: [:])
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let account = NSEntityDescription.insertNewObject(forEntityName: "Account", into: context)
    account.setValue("migration-test-account", forKey: "id")
    try context.save()
    try coordinator.remove(store)
  }

  func testStoreVersion49_MigratesToCurrent_SavedQueueAvailable() throws {
    try createStore(version: .v49)

    let migrator = CoreDataMigrator()
    XCTAssertTrue(migrator.requiresMigration(at: storeURL, toVersion: .current))
    migrator.migrateStore(at: storeURL, toVersion: .current)

    let currentModel = NSManagedObjectModel
      .managedObjectModel(forResource: CoreDataMigrationVersion.current.rawValue)
    guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
      XCTFail("no metadata readable for migrated store")
      return
    }
    XCTAssertTrue(currentModel.isConfiguration(
      withName: nil,
      compatibleWithStoreMetadata: metadata
    ))

    // Open with the current model: seeded data survived and the new
    // SavedQueue entity is queryable.
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
    let store = coordinator.addPersistentStore(at: storeURL, options: [:])
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let accounts = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Account"))
    XCTAssertEqual(accounts.count, 1)
    XCTAssertEqual(accounts.first?.value(forKey: "id") as? String, "migration-test-account")
    let savedQueues = try context
      .fetch(NSFetchRequest<NSManagedObject>(entityName: "SavedQueue"))
    XCTAssertEqual(savedQueues.count, 0)

    let savedQueue = NSEntityDescription.entity(forEntityName: "SavedQueue", in: context)
    XCTAssertNotNil(savedQueue)
    XCTAssertNil(savedQueue?.attributesByName["contextSongIds"])
    XCTAssertNil(savedQueue?.attributesByName["userQueueSongIds"])
    XCTAssertNil(savedQueue?.attributesByName["playerMode"])
    XCTAssertNil(savedQueue?.attributesByName["songCount"])
    XCTAssertNil(savedQueue?.relationshipsByName["toAccount"])
    XCTAssertNotNil(savedQueue?.relationshipsByName["contextPlaylist"])
    XCTAssertNotNil(savedQueue?.relationshipsByName["userQueuePlaylist"])
    XCTAssertEqual(
      savedQueue?.relationshipsByName["contextPlaylist"]?.destinationEntity?.name,
      "Playlist"
    )
    try coordinator.remove(store)
  }

  func testStoreVersion50_NeedsNoMigration() throws {
    try createStore(version: .v50)
    let migrator = CoreDataMigrator()
    XCTAssertFalse(migrator.requiresMigration(at: storeURL, toVersion: .current))
  }
}
