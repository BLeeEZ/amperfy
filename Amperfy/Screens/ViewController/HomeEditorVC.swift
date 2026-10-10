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
final class HomeEditorVC: UICollectionViewController {
  private var orderedSections: [HomeSection]
  private var visibleSections: Set<HomeSection>
  private let onDone: ([HomeSection]) -> ()
  private var diffableDataSource: UICollectionViewDiffableDataSource<Int, HomeSection>!

  init(current: [HomeSection], onDone: @escaping ([HomeSection]) -> ()) {
    self.visibleSections = Set(current)
    // visible sections in their current order, followed by the hidden ones
    self.orderedSections = current + HomeSection.allCases.filter { !current.contains($0) }
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
    applySnapshot(animated: false)
  }

  @objc
  private func doneTapped() {
    // Persist order of only visible sections
    onDone(orderedSections.filter { visibleSections.contains($0) })
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
      cell.contentConfiguration = content

      // same checkbox/reorder handle accessories as the library editor
      cell.accessories = [
        .reorder(),
        .customView(
          configuration: visibleSections.contains(section)
            ? .createIsSelected()
            : .createUnSelected()
        ),
      ]
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
    diffableDataSource.reorderingHandlers.canReorderItem = { [weak self] _ in
      self?.collectionView.isEditing ?? false
    }
    diffableDataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.orderedSections = transaction.finalSnapshot.itemIdentifiers
    }
  }

  private func applySnapshot(animated: Bool) {
    var snapshot = NSDiffableDataSourceSnapshot<Int, HomeSection>()
    snapshot.appendSections([0])
    snapshot.appendItems(orderedSections, toSection: 0)
    diffableDataSource.apply(snapshot, animatingDifferences: animated)
  }

  private func toggleVisibility(of section: HomeSection) {
    if visibleSections.contains(section) {
      visibleSections.remove(section)
    } else {
      visibleSections.insert(section)
    }
    // identifiers are unchanged -> reconfigure the cell to refresh the checkbox
    var snapshot = diffableDataSource.snapshot()
    snapshot.reconfigureItems([section])
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
    toggleVisibility(of: section)
  }
}
