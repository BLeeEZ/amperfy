//
//  HomeEditorVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.11.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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
import UIKit

// MARK: - HomeEditorVC

/// One list with all home sections: the checkbox on the left (tap on the row) toggles the visibility,
/// the handle on the right reorders the row (works with touch and mouse on all platforms).
/// Rows stay where the user put them, also hidden ones.
final class HomeEditorVC: UICollectionViewController {
  private let editor: ReorderableListEditor<HomeSection>
  private let onDone: (_ order: [HomeSection], _ visible: [HomeSection]) -> ()
  private var diffableDataSource: UICollectionViewDiffableDataSource<Int, HomeSection>!

  init(
    order: [HomeSection],
    visible: [HomeSection],
    onDone: @escaping (_ order: [HomeSection], _ visible: [HomeSection]) -> ()
  ) {
    self.editor = ReorderableListEditor(items: order, checkedItems: Set(visible))
    self.onDone = onDone
    super.init(collectionViewLayout: UICollectionViewCompositionalLayout { _, environment in
      let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
      return NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
    })
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Home Preferences"
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped)),
    ]
    // reordering by drag & drop (touch and mouse) only works while the collection view is editing
    collectionView.isEditing = true
    collectionView.allowsSelectionDuringEditing = true
    configureDataSource()
    applySnapshot()
  }

  @objc
  private func doneTapped() {
    onDone(editor.items, editor.orderedCheckedItems)
    if navigationController?.viewControllers.first === self {
      dismiss(animated: true)
    } else {
      navigationController?.popViewController(animated: true)
    }
  }

  private func configureDataSource() {
    let registration = UICollectionView.CellRegistration<UICollectionViewListCell, HomeSection> {
      [weak self] cell, _, section in
      guard let self else { return }
      var content = cell.defaultContentConfiguration()
      content.text = section.title
      // taller rows for a larger hit target
      content.directionalLayoutMargins.top = 12
      content.directionalLayoutMargins.bottom = 12
      cell.contentConfiguration = content
      cell.accessories = editor.editingAccessories(for: section)
    }
    diffableDataSource = UICollectionViewDiffableDataSource<Int, HomeSection>(
      collectionView: collectionView
    ) { collectionView, indexPath, section in
      collectionView.dequeueConfiguredReusableCell(
        using: registration,
        for: indexPath,
        item: section
      )
    }
    editor.installReordering(on: diffableDataSource, collectionView: collectionView)
  }

  private func applySnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Int, HomeSection>()
    snapshot.appendSections([0])
    snapshot.appendItems(editor.items, toSection: 0)
    diffableDataSource.apply(snapshot, animatingDifferences: false)
  }
}

// MARK: UICollectionViewDelegate

extension HomeEditorVC {
  override func collectionView(
    _ collectionView: UICollectionView,
    canEditItemAt indexPath: IndexPath
  )
    -> Bool {
    collectionView.isEditing
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    collectionView.deselectItem(at: indexPath, animated: true)
    guard let section = diffableDataSource.itemIdentifier(for: indexPath) else { return }
    editor.toggle(section, in: diffableDataSource)
  }
}
