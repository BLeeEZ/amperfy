//
//  KeyCommandCollectionViewController copy.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 28.02.24.
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

import UIKit

// MARK: - KeyCommandCollectionViewController

class KeyCommandCollectionViewController: UICollectionViewController {
  lazy var collectionViewKeyCommandsController =
    CollectionViewKeyCommandsController(collectionView: collectionView)

  override func viewDidLoad() {
    super.viewDidLoad()
    setNavBarTitle(title: sceneTitle ?? "")
  }
}

// MARK: - CollectionViewKeyCommandsController

@MainActor
class CollectionViewKeyCommandsController {
  let collectionView: UICollectionView
  let overrideFirstLastIndexPath: IndexPath?

  init(collectionView: UICollectionView, overrideFirstLastIndexPath: IndexPath? = nil) {
    self.collectionView = collectionView
    self.overrideFirstLastIndexPath = overrideFirstLastIndexPath
  }

  private var focussedIndexPath: IndexPath? {
    willSet {
      guard let focussedIndexPath = focussedIndexPath,
            let focussedCell = collectionView.cellForItem(at: focussedIndexPath)
      else { return }
      focussedCell.markAsUnfocused()
    }
    didSet {
      guard let focussedIndexPath = focussedIndexPath,
            collectionView.hasItemAt(indexPath: focussedIndexPath)
      else { return }

      var focussedCell = collectionView.cellForItem(at: focussedIndexPath)
      if focussedCell == nil {
        // cell is not available -> scroll to it and try now to get it
        collectionView.scrollToItem(at: focussedIndexPath, at: .centeredVertically, animated: false)
        focussedCell = collectionView.cellForItem(at: focussedIndexPath)
      } else {
        // cell is available -> scroll to it animated
        collectionView.scrollToItem(at: focussedIndexPath, at: .centeredVertically, animated: true)
      }

      guard let focussedCell = focussedCell else { return }
      focussedCell.markAsFocused()
    }
  }

  func removeFocus() {
    focussedIndexPath = nil
  }

  func interactWithFocus() {
    guard let focussedIndexPath = focussedIndexPath,
          collectionView.hasItemAt(indexPath: focussedIndexPath)
    else { return }

    collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: focussedIndexPath)
  }

  func moveFocusToNext() {
    guard let focussedIndexPath = focussedIndexPath,
          collectionView.numberOfSections > 0
    else {
      self.focussedIndexPath = firstIndexPath
      return
    }

    var focussedSection = focussedIndexPath.section
    if focussedSection >= collectionView.numberOfSections {
      focussedSection = collectionView.numberOfSections - 1
    }
    var focussedRow = focussedIndexPath.row
    if focussedRow >= collectionView.numberOfItems(inSection: focussedSection) {
      focussedRow = collectionView.numberOfItems(inSection: focussedSection) - 1
    }

    if focussedRow == (collectionView.numberOfItems(inSection: focussedSection) - 1) {
      // jumb to next section
      var nextSection = focussedSection + 1
      while nextSection < collectionView.numberOfSections {
        if collectionView.numberOfItems(inSection: nextSection) > 0 {
          break
        }
        nextSection += 1
      }
      if nextSection >= collectionView.numberOfSections {
        // the last row was selcted -> jump to first
        self.focussedIndexPath = firstIndexPath
      } else {
        self.focussedIndexPath = IndexPath(item: 0, section: nextSection)
      }
    } else {
      self.focussedIndexPath = IndexPath(item: focussedRow + 1, section: focussedSection)
    }
  }

  func moveFocusToPrevious() {
    guard let focussedIndexPath = focussedIndexPath,
          collectionView.numberOfSections > 0
    else {
      self.focussedIndexPath = lastIndexPath
      return
    }

    var focussedSection = focussedIndexPath.section
    if focussedSection >= collectionView.numberOfSections {
      focussedSection = collectionView.numberOfSections - 1
    }
    var focussedRow = focussedIndexPath.row
    if focussedRow >= collectionView.numberOfItems(inSection: focussedSection) {
      focussedRow = collectionView.numberOfItems(inSection: focussedSection) - 1
    }

    if focussedRow == 0 {
      // jumb to previous section which contains rows
      var prevSection = focussedSection - 1
      while prevSection >= 0 {
        if collectionView.numberOfItems(inSection: prevSection) > 0 {
          break
        }
        prevSection -= 1
      }
      if prevSection < 0 {
        // the first row was selcted -> jump to last
        self.focussedIndexPath = lastIndexPath
      } else {
        self.focussedIndexPath = IndexPath(
          item: collectionView.numberOfItems(inSection: prevSection) - 1,
          section: prevSection
        )
      }
    } else {
      self.focussedIndexPath = IndexPath(item: focussedRow - 1, section: focussedSection)
    }
  }

  private var lastIndexPath: IndexPath? {
    guard collectionView.numberOfSections > 0 else { return nil }
    if let overrideFirstLastIndexPath = overrideFirstLastIndexPath {
      return overrideFirstLastIndexPath
    }
    var lastSectionWithRows = collectionView.numberOfSections
    while lastSectionWithRows >= 0 {
      lastSectionWithRows -= 1
      if collectionView.numberOfItems(inSection: lastSectionWithRows) > 0 {
        break
      }
    }
    if lastSectionWithRows >= 0 {
      return IndexPath(
        item: collectionView.numberOfItems(inSection: lastSectionWithRows) - 1,
        section: lastSectionWithRows
      )
    } else {
      return nil
    }
  }

  private var firstIndexPath: IndexPath? {
    guard collectionView.numberOfSections > 0 else { return nil }
    if let overrideFirstLastIndexPath = overrideFirstLastIndexPath {
      return overrideFirstLastIndexPath
    }
    var firstSectionWithRows = -1
    while firstSectionWithRows < collectionView.numberOfSections {
      firstSectionWithRows += 1
      if collectionView.numberOfItems(inSection: firstSectionWithRows) > 0 {
        break
      }
    }
    if firstSectionWithRows != collectionView.numberOfSections {
      return IndexPath(item: 0, section: firstSectionWithRows)
    } else {
      return nil
    }
  }
}
