//
//  ReorderableListEditor.swift
//  Amperfy
//
//  Created by Chrizz Gelbach on 23.10.26.
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

import UIKit

// MARK: - ReorderableListEditor

/// Edit behaviour of a list in a `UICollectionView` (list layout) with a diffable data source:
/// the handle on the right reorders a row by drag & drop (touch and mouse, also on Mac Catalyst),
/// the optional checkbox on the left is toggled by tapping the row.
/// Rows are never moved automatically: the order is always the one arranged by the user.
///
/// The data source may contain further items (e.g. fixed entries at the top) which are not managed
/// by the editor: they can't be moved and managed items can't be moved past them.
/// The managed items must be shown as one contiguous block.
/// Reordering only works while the collection view is editing.
@MainActor
final class ReorderableListEditor<Item: Hashable & Sendable> {
  /// all managed items in the order arranged by the user
  private(set) var items: [Item]
  private(set) var checkedItems: Set<Item>
  /// `false`: no checkbox, rows can only be reordered
  let isCheckable: Bool

  /// Rows with checkbox and reorder handle.
  init(items: [Item], checkedItems: Set<Item>) {
    self.items = items
    self.checkedItems = checkedItems
    self.isCheckable = true
  }

  /// Rows with reorder handle only, e.g. the items of a playlist.
  init(reorderOnly items: [Item]) {
    self.items = items
    self.checkedItems = []
    self.isCheckable = false
  }

  /// Replaces the items (e.g. after the settings changed elsewhere); the installed handlers stay valid.
  func reset(items: [Item], checkedItems: Set<Item>) {
    self.items = items
    self.checkedItems = isCheckable ? checkedItems : []
  }

  /// checked items in the order arranged by the user
  var orderedCheckedItems: [Item] {
    items.filter { checkedItems.contains($0) }
  }

  func isChecked(_ item: Item) -> Bool {
    checkedItems.contains(item)
  }

  /// Accessories of a managed row: reorder handle and checkbox (both only visible while editing).
  func editingAccessories(for item: Item) -> [UICellAccessory] {
    var accessories: [UICellAccessory] = [.reorder()]
    if isCheckable {
      accessories.append(.customView(
        configuration: isChecked(item) ? .createIsSelected() : .createUnSelected()
      ))
    }
    return accessories
  }

  /// Installs the reordering handlers of the data source to keep `items` in sync.
  func installReordering<Section: Hashable & Sendable>(
    on dataSource: UICollectionViewDiffableDataSource<Section, Item>,
    collectionView: UICollectionView
  ) {
    dataSource.reorderingHandlers.canReorderItem = { [weak self, weak collectionView] item in
      guard let self, let collectionView else { return false }
      return collectionView.isEditing && items.contains(item)
    }
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      guard let self else { return }
      let managed = Set(items)
      items = transaction.finalSnapshot.itemIdentifiers.filter { managed.contains($0) }
    }
  }

  /// Keeps a moved row inside the range of the managed rows.
  /// To be called from `collectionView(_:targetIndexPathForMoveOfItemFromOriginalIndexPath:...)`.
  func targetIndexPath<Section: Hashable & Sendable>(
    forProposed proposedIndexPath: IndexPath,
    in dataSource: UICollectionViewDiffableDataSource<Section, Item>
  )
    -> IndexPath {
    // the managed rows are contiguous -> the first and the last one define the range
    guard let firstItem = items.first, let lastItem = items.last,
          let first = dataSource.indexPath(for: firstItem),
          let last = dataSource.indexPath(for: lastItem)
    else { return proposedIndexPath }
    let row = min(max(proposedIndexPath.row, first.row), last.row)
    return IndexPath(row: row, section: first.section)
  }

  /// Toggles the checkbox of a row without moving it.
  func toggle<Section: Hashable & Sendable>(
    _ item: Item,
    in dataSource: UICollectionViewDiffableDataSource<Section, Item>
  ) {
    guard isCheckable, items.contains(item) else { return }
    if checkedItems.contains(item) {
      checkedItems.remove(item)
    } else {
      checkedItems.insert(item)
    }
    // identifiers are unchanged -> reconfigure the cell to refresh the checkbox
    var snapshot = dataSource.snapshot()
    snapshot.reconfigureItems([item])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
}
