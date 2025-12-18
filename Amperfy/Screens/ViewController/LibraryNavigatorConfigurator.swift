//
//  LibraryItemConfigurator.swift
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

import AmperfyKit
import UIKit

// MARK: - LibraryNavigatorItem

final class LibraryNavigatorItem: Hashable, Sendable {
  let id = UUID()
  let title: String
  let library: LibraryDisplayType?
  @MainActor
  var isSelected = false
  let isInteractable: Bool
  let tab: TabNavigatorItem?

  init(
    title: String,
    library: LibraryDisplayType? = nil,
    isSelected: Bool = false,
    isInteractable: Bool = true,
    tab: TabNavigatorItem? = nil
  ) {
    self.title = title
    self.library = library
    self.isSelected = isSelected
    self.isInteractable = isInteractable
    self.tab = tab
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (
    lhs: LibraryNavigatorItem,
    rhs: LibraryNavigatorItem
  )
    -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - TabNavigatorItem

enum TabNavigatorItem: Int, Hashable, CaseIterable {
  case search
  case home

  var title: String {
    switch self {
    case .home: return "Home"
    case .search: return "Search"
    }
  }

  @MainActor
  var icon: UIImage {
    switch self {
    case .home: return .home
    case .search: return .search
    }
  }

  @MainActor
  func getController(account: Account) -> UIViewController {
    switch self {
    case .home: return AppStoryboard.Main.segueToHome(account: account)
    case .search: return AppStoryboard.Main.segueToSearch(account: account)
    }
  }
}

typealias SideBarDiffableDataSource = UICollectionViewDiffableDataSource<Int, LibraryNavigatorItem>

// MARK: - LibraryNavigatorConfigurator

@MainActor
class LibraryNavigatorConfigurator: NSObject {
  static let sectionHeaderElementKind = "section-header-element-kind"

  private let account: Account
  private var data = [LibraryNavigatorItem]()
  private let offsetData: [LibraryNavigatorItem]
  private var collectionView: UICollectionView!
  private var dataSource: SideBarDiffableDataSource!
  private let layoutConfig: UICollectionLayoutListConfiguration
  private let pressedOnLibraryItemCB: (_: LibraryNavigatorItem) -> ()

  #if targetEnvironment(macCatalyst)
    private var preEditItem: LibraryNavigatorItem?
  #endif

  private var editButton: UIBarButtonItem!
  private var librarySettings = LibraryDisplaySettings.defaultSettings
  private var libraryInUse = [LibraryNavigatorItem]()
  private var libraryNotUsed = [LibraryNavigatorItem]()

  init(
    account: Account,
    offsetData: [LibraryNavigatorItem],
    librarySettings: LibraryDisplaySettings,
    layoutConfig: UICollectionLayoutListConfiguration,
    pressedOnLibraryItemCB: @escaping (@MainActor (_: LibraryNavigatorItem) -> ())
  ) {
    self.account = account
    self.offsetData = offsetData
    self.librarySettings = librarySettings
    self.layoutConfig = layoutConfig
    self.pressedOnLibraryItemCB = pressedOnLibraryItemCB
    super.init()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleLibraryItemsChanged(notification:)),
      name: .LibraryItemsChanged,
      object: nil
    )
  }

  @objc
  func handleLibraryItemsChanged(notification: Notification) {
    refresh(
      librarySettings: appDelegate.storage.settings.accounts
        .getSetting(account.info).read.libraryDisplaySettings
    )
  }

  @MainActor
  func viewDidLoad(navigationItem: UINavigationItem, collectionView: UICollectionView) {
    self.collectionView = collectionView
    editButton = UIBarButtonItem(
      title: "Edit",
      style: .plain,
      target: self,
      action: #selector(editingPressed)
    )
    navigationItem.rightBarButtonItems = [editButton]
    libraryInUse = librarySettings.inUse.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0
    ) }
    libraryNotUsed = librarySettings.notUsed.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0
    ) }
    self.collectionView.allowsSelectionDuringEditing = true
    self.collectionView.delegate = self
    self.collectionView.collectionViewLayout = createLayout() // 1 Configure the layout
    configureDataSource() // 2 configure the data Source
    applyInitialSnapshots() // 3 Apply the snapshots.
  }

  func viewIsAppearing(navigationItem: UINavigationItem, collectionView: UICollectionView) {
    #if targetEnvironment(macCatalyst) // ok
      if self.collectionView.indexPathsForSelectedItems?.first == nil {
        // select Home
        self.collectionView.selectItem(
          at: IndexPath(row: TabNavigatorItem.home.rawValue, section: 0),
          animated: false,
          scrollPosition: .top
        )
      }
    #endif
  }

  @MainActor @objc
  private func editingPressed() {
    let isInEditMode = !collectionView.isEditing
    editButton.title = isInEditMode ? "Done" : "Edit"
    editButton.style = isInEditMode ? .prominent : .plain

    if isInEditMode {
      #if targetEnvironment(macCatalyst) // ok
        let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first ?? .zero
        preEditItem = dataSource.itemIdentifier(for: selectedIndexPath)
      #endif

      collectionView.isEditing.toggle()
      var snapshot = dataSource.snapshot(for: 0)
      snapshot.append(libraryNotUsed)
      dataSource.apply(snapshot, to: 0, animatingDifferences: true)
    } else {
      collectionView.isEditing.toggle()
      var snapshot = dataSource.snapshot(for: 0)
      let inUse = snapshot.items.filter { $0.isSelected && ($0.library != nil) }.compactMap { $0 }
      struct Temp {
        let indexPath: IndexPath
        let item: LibraryNavigatorItem
      }
      let inUseItems = inUse.compactMap {
        if let indexPath = dataSource.indexPath(for: $0) {
          return Temp(indexPath: indexPath, item: $0)
        } else {
          return nil
        }
      }
      .sorted(by: { $0.indexPath < $1.indexPath })
      .compactMap { $0.item }
      libraryInUse = inUseItems

      var snapshot2 = dataSource.snapshot(for: 0)
      if !offsetData.isEmpty {
        let offsetItems = Array(snapshot.items[0 ... (offsetData.count - 1)])
        snapshot2.delete(offsetItems)
      }
      snapshot2.delete(libraryInUse)
      libraryNotUsed = snapshot2.items
      snapshot.delete(libraryNotUsed)

      appDelegate.storage.settings.accounts
        .updateSetting(account.info) { accountSetting in
          accountSetting.libraryDisplaySettings = LibraryDisplaySettings(
            inUse: libraryInUse
              .compactMap { $0.library }
          )
        }
      dataSource.apply(snapshot, to: 0, animatingDifferences: true)

      // Restore selection after editing endet on macOS
      #if targetEnvironment(macCatalyst) // ok
        let indexPath = preEditItem != nil ? dataSource.indexPath(for: preEditItem!) : .zero
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
      #endif

      NotificationCenter.default.post(name: .LibraryItemsChanged, object: nil, userInfo: nil)
    }
  }

  func refresh(librarySettings: LibraryDisplaySettings) {
    #if targetEnvironment(macCatalyst) // ok
      let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first ?? .zero
      preEditItem = dataSource.itemIdentifier(for: selectedIndexPath)
    #endif

    var snapshot = dataSource.snapshot(for: 0)
    snapshot.deleteAll()

    libraryInUse = librarySettings.inUse.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0,
      isSelected: true
    ) }
    #if targetEnvironment(macCatalyst) // ok
      // update the preEditItem based on title
      preEditItem = libraryInUse.first(where: { $0.title == preEditItem?.title })
    #endif
    libraryNotUsed = librarySettings.notUsed.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0
    ) }

    snapshot.append(offsetData)
    snapshot.append(libraryInUse)
    dataSource.apply(snapshot, to: 0, animatingDifferences: true)

    // Restore selection after refresh endet on macOS
    #if targetEnvironment(macCatalyst) // ok
      if let preEditItem, let indexPath = dataSource.indexPath(for: preEditItem) {
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
      }
    #endif
  }

  private func createLayout() -> UICollectionViewLayout {
    let sectionProvider = { (
      sectionIndex: Int,
      layoutEnvironment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection? in
      let section = NSCollectionLayoutSection.list(
        using: self.layoutConfig,
        layoutEnvironment: layoutEnvironment
      )
      let headerFooterSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(.leastNonzeroMagnitude)
      )
      let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerFooterSize,
        elementKind: Self.sectionHeaderElementKind, alignment: .top
      )
      section.boundarySupplementaryItems = [sectionHeader]

      return section
    }
    return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider)
  }

  @MainActor
  private func configureDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<
      UICollectionViewListCell,
      LibraryNavigatorItem
    > { cell, indexPath, item in
      if !item.isInteractable {
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        cell.accessories = []
        cell.contentConfiguration = content
      } else if let libraryItem = item.library {
        var content = cell.defaultContentConfiguration()
        Self.configureForLibrary(contentView: &content, libraryItem: libraryItem)

        #if targetEnvironment(macCatalyst) // ok
          cell.accessories = []
        #else
          cell.accessories = [.disclosureIndicator(displayed: .whenNotEditing)]
        #endif

        if item.isSelected {
          cell.accessories.append(.reorder())
          cell.accessories.append(.customView(configuration: .createIsSelected()))
        } else {
          cell.accessories.append(.customView(configuration: .createUnSelected()))
        }
        cell.contentConfiguration = content
      } else if let tabItem = item.tab {
        #if targetEnvironment(macCatalyst) // ok
          cell.accessories = []
        #else
          cell.accessories = [.disclosureIndicator()]
        #endif
        var content = cell.defaultContentConfiguration()
        content.text = tabItem.title
        content.image = tabItem.icon.withRenderingMode(.alwaysTemplate)
        cell.contentConfiguration = content
      }
      cell.indentationLevel = 0
    }

    /// 1 - header registration
    let headerRegistration = UICollectionView.SupplementaryRegistration
    <UICollectionViewListCell>(elementKind: Self.sectionHeaderElementKind) {
      (supplementaryView, string, indexPath) in
      supplementaryView.isHidden = true
    }
    // 2 - data source
    dataSource = SideBarDiffableDataSource(collectionView: collectionView) {
      collectionView, indexPath, item -> UICollectionViewCell? in
      return collectionView.dequeueConfiguredReusableCell(
        using: cellRegistration,
        for: indexPath,
        item: item
      )
    }
    /// 3 - data source supplementaryViewProvider
    dataSource.supplementaryViewProvider = { view, kind, index in
      self.collectionView.dequeueConfiguredReusableSupplementary(
        using: headerRegistration,
        for: index
      )
    }

    /// 4 - data source reordering
    dataSource.reorderingHandlers.canReorderItem = { [weak self] item in
      let isEdit = self?.collectionView.isEditing ?? false
      return item.isSelected && isEdit && (item.tab == nil)
    }
  }

  @MainActor
  static func configureForLibrary(
    contentView: inout UIListContentConfiguration,
    libraryItem: LibraryDisplayType
  ) {
    contentView.text = libraryItem.displayName
    contentView.image = libraryItem.image.withRenderingMode(.alwaysTemplate)
    if libraryItem == .podcasts {
      // special case for podcast icon
      contentView.image = libraryItem.image.withRenderingMode(.alwaysTemplate)
    }
    let imageSize = CGSize(width: 35.0, height: 25.0)
    contentView.imageProperties.maximumSize = imageSize
    contentView.imageProperties.reservedLayoutSize = imageSize
  }

  private func applyInitialSnapshots() {
    var snapshot = NSDiffableDataSourceSnapshot<Int, LibraryNavigatorItem>()
    snapshot.appendSections([0])
    dataSource.apply(snapshot, animatingDifferences: false)

    data.append(contentsOf: offsetData)
    let libraryItems = librarySettings.inUse.map { LibraryNavigatorItem(
      title: $0.displayName,
      library: $0,
      isSelected: true
    ) }
    data.append(contentsOf: libraryItems)

    var outlineSnapshot = NSDiffableDataSourceSectionSnapshot<LibraryNavigatorItem>()
    outlineSnapshot.append(data)
    dataSource.apply(outlineSnapshot, to: 0, animatingDifferences: false)
  }
}

// MARK: UICollectionViewDelegate

extension LibraryNavigatorConfigurator: UICollectionViewDelegate {
  func collectionView(
    _ collectionView: UICollectionView,
    shouldSelectItemAt indexPath: IndexPath
  )
    -> Bool {
    if collectionView.isEditing {
      return indexPath.row >= offsetData.count
    } else if let item = dataSource.itemIdentifier(for: indexPath) {
      return item.isInteractable
    } else {
      return false
    }
  }

  func collectionView(
    _ collectionView: UICollectionView,
    canEditItemAt indexPath: IndexPath
  )
    -> Bool {
    collectionView.isEditing
  }

  func collectionView(
    _ collectionView: UICollectionView,
    targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
    atCurrentIndexPath currentIndexPath: IndexPath,
    toProposedIndexPath proposedIndexPath: IndexPath
  )
    -> IndexPath {
    let selectedRowsCount = dataSource.snapshot().itemIdentifiers.filter(\.isSelected).count
    if proposedIndexPath.row >= offsetData.count + selectedRowsCount {
      // don't allow reordering unused items
      return IndexPath(row: offsetData.count + selectedRowsCount - 1, section: 0)
    } else if proposedIndexPath.row >= offsetData.count {
      return proposedIndexPath
    } else {
      return IndexPath(row: offsetData.count, section: 0)
    }
  }

  func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    // handel selection
    guard !collectionView.isEditing else {
      collectionView.deselectItem(at: indexPath, animated: true)
      guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
      var snapshot = dataSource.snapshot()

      if !item.isSelected {
        if let lastInUsedItem = snapshot.itemIdentifiers.last(where: \.isSelected),
           lastInUsedItem != item {
          // move freshly selected item to end of selected items
          snapshot.moveItem(item, afterItem: lastInUsedItem)
          dataSource.apply(snapshot, animatingDifferences: true)
        } else if let firstItem = snapshot.itemIdentifiers[offsetData.count...].first,
                  firstItem != item {
          // no active item exists
          snapshot.moveItem(item, beforeItem: firstItem)
          dataSource.apply(snapshot, animatingDifferences: true)
        }
      }

      if item.isSelected, let lib = item.library {
        if let beforeUnusedInsertionItem = snapshot.itemIdentifiers
          .filter({ !$0.isSelected && $0.library != nil })
          .first(where: { $0.library!.rawValue >= lib.rawValue }),
          beforeUnusedInsertionItem != item {
          // move deselected item to its correct position based on the ordering defined in LibraryDisplaySettings
          snapshot.moveItem(item, beforeItem: beforeUnusedInsertionItem)
          dataSource.apply(snapshot, animatingDifferences: true)
        } else if let lastItem = snapshot.itemIdentifiers.last, lastItem != item {
          // no insertion index exists, therefore this must be the last element
          snapshot.moveItem(item, afterItem: lastItem)
          dataSource.apply(snapshot, animatingDifferences: true)
        }
      }

      // don't animate selection
      item.isSelected.toggle()
      snapshot.reconfigureItems([item])
      dataSource.apply(snapshot, animatingDifferences: false)
      return
    }
    // Retrieve the item identifier using index path.
    // The item identifier we get will be the selected data item

    guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else {
      return
    }

    pressedOnLibraryItemCB(selectedItem)
  }
}

extension IndexPath {
  static let zero = IndexPath(row: 0, section: 0)
}
