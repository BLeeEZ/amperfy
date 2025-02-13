//
//  CoreDataHelper.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 30.12.19.
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

@testable import AmperfyKit
import CoreData
import Foundation

@MainActor
class CoreDataHelper {
  let seeder: CoreDataSeeder
  lazy var persistentContainer = {
    NSPersistentContainer(
      name: "Amperfy",
      managedObjectModel: CoreDataPersistentManager.managedObjectModel
    )
  }()

  init() {
    self.seeder = CoreDataSeeder()
  }

  func createInMemoryManagedObjectContext() -> NSManagedObjectContext {
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false // Make it simpler in test env

    persistentContainer.persistentStoreDescriptions = [description]
    persistentContainer.loadPersistentStores { description, error in
      // Check if the data store is in memory
      precondition(description.type == NSInMemoryStoreType)

      // Check if creating container wrong
      if let error = error {
        fatalError("Create an in-mem coordinator failed \(error)")
      }
    }
    return persistentContainer.viewContext
  }

  func clearContext(context: NSManagedObjectContext) {
    for entityName in LibraryStorage.entitiesToDelete {
      let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
      let objs = try! context.fetch(fetchRequest)
      for case let obj as NSManagedObject in objs {
        context.delete(obj)
      }
      try! context.save()
    }
  }

  func createSeededStorage() -> LibraryStorage {
    let context = createInMemoryManagedObjectContext()
    clearContext(context: context)
    let library = LibraryStorage(context: context)
    seeder.seed(context: context)
    return library
  }
}
