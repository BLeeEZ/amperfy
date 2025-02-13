//
//  Created by William Boles.
//  Copyright © 2017 William Boles. All rights reserved.
//
import CoreData
import Foundation

extension NSManagedObjectModel {
  // MARK: - Compatible

  static func compatibleModelForStoreMetadata(_ metadata: [String: Any]) -> NSManagedObjectModel? {
    let mainBundle = Bundle.main
    return NSManagedObjectModel.mergedModel(from: [mainBundle], forStoreMetadata: metadata)
  }
}

extension NSManagedObjectModel {
  // MARK: - Resource

  static func managedObjectModel(forResource resource: String) -> NSManagedObjectModel {
    let mainBundle = Bundle.main
    let subdirectory = "Amperfy.momd"

    var omoURL: URL?
    if #available(iOS 11, *) {
      omoURL = mainBundle.url(
        forResource: resource,
        withExtension: "omo",
        subdirectory: subdirectory
      ) // optimized model file
    }
    let momURL = mainBundle.url(
      forResource: resource,
      withExtension: "mom",
      subdirectory: subdirectory
    )

    guard let url = omoURL ?? momURL else {
      fatalError("unable to find model in bundle")
    }

    guard let model = NSManagedObjectModel(contentsOf: url) else {
      fatalError("unable to load model in bundle")
    }

    return model
  }
}

extension NSPersistentStoreCoordinator {
  // MARK: - Destroy

  static func destroyStore(at storeURL: URL) {
    do {
      let persistentStoreCoordinator =
        NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
      try persistentStoreCoordinator.destroyPersistentStore(
        at: storeURL,
        ofType: NSSQLiteStoreType,
        options: nil
      )
    } catch {
      fatalError("failed to destroy persistent store at \(storeURL), error: \(error)")
    }
  }

  // MARK: - Replace

  static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) {
    do {
      let persistentStoreCoordinator =
        NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
      try persistentStoreCoordinator.replacePersistentStore(
        at: targetURL,
        destinationOptions: nil,
        withPersistentStoreFrom: sourceURL,
        sourceOptions: nil,
        ofType: NSSQLiteStoreType
      )
    } catch {
      fatalError(
        "failed to replace persistent store at \(targetURL) with \(sourceURL), error: \(error)"
      )
    }
  }

  // MARK: - Meta

  static func metadata(at storeURL: URL) -> [String: Any]? {
    try? NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType,
      at: storeURL,
      options: nil
    )
  }

  // MARK: - Add

  func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) -> NSPersistentStore {
    do {
      return try addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: storeURL,
        options: options
      )
    } catch {
      fatalError("failed to add persistent store to coordinator, error: \(error)")
    }
  }
}
