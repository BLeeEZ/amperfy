//
//  SingleSnapshotFetchedResultsTableViewController.swift
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

// MARK: - BasicUITableViewDiffableDataSource

class BasicUITableViewDiffableDataSource: UITableViewDiffableDataSource<Int, NSManagedObjectID> {
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    true
  }

  override func tableView(
    _ tableView: UITableView,
    moveRowAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    guard let fromObject = itemIdentifier(for: sourceIndexPath),
          sourceIndexPath != destinationIndexPath else { return }

    var snap = snapshot()
    snap.deleteItems([fromObject])

    if let toObject = itemIdentifier(for: destinationIndexPath) {
      let isAfter = destinationIndexPath.row > sourceIndexPath.row

      if isAfter {
        snap.insertItems([fromObject], afterItem: toObject)
      } else {
        snap.insertItems([fromObject], beforeItem: toObject)
      }
    } else {
      snap.appendItems([fromObject], toSection: sourceIndexPath.section)
    }

    apply(snap, animatingDifferences: true)
  }

  // Override to support conditional rearranging of the table view.
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    true
  }

  override func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    guard editingStyle == .delete else { return }
    guard let targetObject = itemIdentifier(for: indexPath) else { return }
    var snap = snapshot()
    snap.deleteItems([targetObject])
    apply(snap, animatingDifferences: true)
  }
}

// MARK: - BasicUICollectionViewDiffableDataSource

class BasicUICollectionViewDiffableDataSource: UICollectionViewDiffableDataSource<
  Int,
  NSManagedObjectID
> {
  override func collectionView(
    _ collectionView: UICollectionView,
    canMoveItemAt indexPath: IndexPath
  )
    -> Bool {
    true
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    moveItemAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    guard let fromObject = itemIdentifier(for: sourceIndexPath),
          sourceIndexPath != destinationIndexPath else { return }

    var snap = snapshot()
    snap.deleteItems([fromObject])

    if let toObject = itemIdentifier(for: destinationIndexPath) {
      let isAfter = destinationIndexPath.row > sourceIndexPath.row

      if isAfter {
        snap.insertItems([fromObject], afterItem: toObject)
      } else {
        snap.insertItems([fromObject], beforeItem: toObject)
      }
    } else {
      snap.appendItems([fromObject], toSection: sourceIndexPath.section)
    }

    apply(snap, animatingDifferences: true)
  }
}

// MARK: - SingleSnapshotFetchedResultsTableViewController

class SingleSnapshotFetchedResultsTableViewController<ResultType>:
  BasicFetchedResultsTableViewController<ResultType>,
  @preconcurrency NSFetchedResultsControllerDelegate
  where ResultType: NSFetchRequestResult {
  var diffableDataSource: BasicUITableViewDiffableDataSource?
  var snapshotDidChange: (() -> ())?
  let account: Account

  init(style: UITableView.Style, account: Account) {
    self.account = account
    super.init(style: style)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    /// Store the data source in an instance property to make sure it's retained.
    diffableDataSource = createDiffableDataSource()
    /// Assign the data source to your collection view.
    tableView.dataSource = diffableDataSource
  }

  /// need to be overriden in child class
  func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
    fatalError("Should have been overriden in child class")
  }

  /// This will override the NSFetchedResultsController handling of the super class -> Only use snapshots
  func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
  ) {
    MainActor.assumeIsolated {
      guard let dataSource = tableView?.dataSource as? UITableViewDiffableDataSource<
        Int,
        NSManagedObjectID
      > else {
        assertionFailure("The data source has not implemented snapshot support while it should")
        return
      }
      var snapshot = snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
      let currentSnapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<
        Int,
        NSManagedObjectID
      >

      let reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers
        .compactMap { itemIdentifier in
          guard let currentIndex = currentSnapshot.indexOfItem(itemIdentifier),
                let index = snapshot.indexOfItem(itemIdentifier), index == currentIndex else {
            return nil
          }
          guard let existingObject = try? controller.managedObjectContext
            .existingObject(with: itemIdentifier), existingObject.isUpdated else { return nil }
          return itemIdentifier
        }
      snapshot.reconfigureItems(reloadIdentifiers)

      dataSource.apply(
        snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>,
        animatingDifferences: false
      )
      self.snapshotDidChange?()
    }
  }
}

extension UITableViewDiffableDataSource {
  func exectueAfterAnimation(body: @escaping () -> ()) {
    Task { @MainActor in
      body()
    }
  }
}
