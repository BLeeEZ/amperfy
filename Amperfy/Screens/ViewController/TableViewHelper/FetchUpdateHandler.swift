//
//  FetchUpdateHandler.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 23.02.24.
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

import AmperfyKit
import CoreData
import UIKit

@MainActor
class FetchUpdatePerObjectHandler: NSObject, NSFetchedResultsControllerDelegate {
  private let tableView: UITableView

  public var changesDidEnd: VoidFunctionCallback?

  public init(tableView: UITableView) {
    self.tableView = tableView
  }

  nonisolated public func controllerWillChangeContent(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>
  ) {
    MainActor.assumeIsolated {
      tableView.beginUpdates()
    }
  }

  nonisolated public func controllerDidChangeContent(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>
  ) {
    MainActor.assumeIsolated {
      tableView.endUpdates()
      changesDidEnd?()
    }
  }

  nonisolated public func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange anObject: Any,
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    MainActor.assumeIsolated {
      self.applyChangesFromFetchedResultsController(
        at: indexPath,
        for: type,
        newIndexPath: newIndexPath
      )
    }
  }

  public func applyChangesOfMultiRowType(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange anObject: Any,
    determinedSection section: Int,
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    var adjustedIndexPath: IndexPath?
    if let indexPath = indexPath {
      adjustedIndexPath = IndexPath(row: indexPath.row, section: section)
    }
    var adjustedNewIndexPath: IndexPath?
    if let newIndexPath = newIndexPath {
      adjustedNewIndexPath = IndexPath(row: newIndexPath.row, section: section)
    }
    applyChangesFromFetchedResultsController(
      at: adjustedIndexPath,
      for: type,
      newIndexPath: adjustedNewIndexPath
    )
  }

  private func applyChangesFromFetchedResultsController(
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    switch type {
    case .insert:
      tableView.insertRows(at: [newIndexPath!], with: .bottom)
    case .delete:
      tableView.deleteRows(at: [indexPath!], with: .left)
    case .move:
      if indexPath! != newIndexPath! {
        tableView.insertRows(at: [newIndexPath!], with: .bottom)
        tableView.deleteRows(at: [indexPath!], with: .left)
      } else {
        tableView.insertRows(at: [newIndexPath!], with: .none)
        tableView.deleteRows(at: [indexPath!], with: .none)
      }
    case .update:
      tableView.reconfigureRows(at: [indexPath!])
    @unknown default:
      break
    }
  }

  nonisolated public func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange sectionInfo: NSFetchedResultsSectionInfo,
    atSectionIndex sectionIndex: Int,
    for type: NSFetchedResultsChangeType
  ) {
    MainActor.assumeIsolated {
      let indexSet = IndexSet(integer: sectionIndex)
      switch type {
      case .insert:
        tableView.insertSections(indexSet, with: .automatic)
      case .delete:
        tableView.deleteSections(indexSet, with: .automatic)
      default:
        break
      }
    }
  }
}
