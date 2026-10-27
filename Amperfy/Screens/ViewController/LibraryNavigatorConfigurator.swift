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
  let isInteractable: Bool
  let tab: TabNavigatorItem?

  init(
    title: String,
    library: LibraryDisplayType? = nil,
    isInteractable: Bool = true,
    tab: TabNavigatorItem? = nil
  ) {
    self.title = title
    self.library = library
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
  private let offsetData: [LibraryNavigatorItem]
  private var collectionView: UICollectionView!
  private var dataSource: SideBarDiffableDataSource!
  private let layoutConfig: UICollectionLayoutListConfiguration
  private let pressedOnLibraryItemCB: (_: LibraryNavigatorItem) -> ()

  #if targetEnvironment(macCatalyst)
    private var preEditItem: LibraryNavigatorItem?
  #endif

  private var editButton: UIBarButtonItem!
  /// one item per library type for the whole lifetime: unchanged items keep their identity on refresh
  private let libraryItems: [LibraryDisplayType: LibraryNavigatorItem]
  /// all library items in the order arranged by the user, checked ones are in use
  private let editor: ReorderableListEditor<LibraryNavigatorItem>

  init(
    account: Account,
    offsetData: [LibraryNavigatorItem],
    librarySettings: LibraryDisplaySettings,
    layoutConfig: UICollectionLayoutListConfiguration,
    pressedOnLibraryItemCB: @escaping (@MainActor (_: LibraryNavigatorItem) -> ())
  ) {
    self.account = account
    self.offsetData = offsetData
    self.libraryItems = Dictionary(uniqueKeysWithValues: LibraryDisplayType.allCases.map {
      ($0, LibraryNavigatorItem(title: $0.displayName, library: $0))
    })
    self.editor = ReorderableListEditor(items: [], checkedItems: [])
    self.layoutConfig = layoutConfig
    self.pressedOnLibraryItemCB = pressedOnLibraryItemCB
    super.init()
    resetEditor(librarySettings: librarySettings)

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
      // show the items not in use at the position the user put them
      applyLibraryItems(animated: true)
    } else {
      collectionView.isEditing.toggle()
      let newSettings = LibraryDisplaySettings(
        order: editor.items.compactMap { $0.library },
        inUse: Set(editor.checkedItems.compactMap { $0.library })
      )
      appDelegate.storage.settings.accounts
        .updateSetting(account.info) { accountSetting in
          accountSetting.libraryDisplaySettings = newSettings
        }
      applyLibraryItems(animated: true)

      // Restore selection after editing endet on macOS
      #if targetEnvironment(macCatalyst) // ok
        let indexPath = preEditItem != nil ? dataSource.indexPath(for: preEditItem!) : .zero
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
      #endif

      NotificationCenter.default.post(name: .LibraryItemsChanged, object: nil, userInfo: nil)
    }
  }

  func refresh(librarySettings: LibraryDisplaySettings) {
    // not loaded yet, or editing: keep the pending changes of the user, they are saved on Done
    guard dataSource != nil, !collectionView.isEditing else { return }

    #if targetEnvironment(macCatalyst) // ok
      let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first ?? .zero
      preEditItem = dataSource.itemIdentifier(for: selectedIndexPath)
    #endif

    resetEditor(librarySettings: librarySettings)
    applyLibraryItems(animated: true)
    // items keep their identity -> refresh the checkboxes of the cells
    var snapshot = dataSource.snapshot()
    snapshot.reconfigureItems(snapshot.itemIdentifiers)
    dataSource.apply(snapshot, animatingDifferences: false)

    // Restore selection after refresh endet on macOS
    #if targetEnvironment(macCatalyst) // ok
      if let preEditItem, let indexPath = dataSource.indexPath(for: preEditItem) {
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
      }
    #endif
  }

  private func resetEditor(librarySettings: LibraryDisplaySettings) {
    editor.reset(
      items: librarySettings.order.compactMap { libraryItems[$0] },
      checkedItems: Set(librarySettings.inUse.compactMap { libraryItems[$0] })
    )
  }

  /// fixed items followed by the library items: all while editing, otherwise only the ones in use
  private func applyLibraryItems(animated: Bool) {
    var snapshot = NSDiffableDataSourceSectionSnapshot<LibraryNavigatorItem>()
    snapshot.append(offsetData)
    snapshot.append(collectionView.isEditing ? editor.items : editor.orderedCheckedItems)
    dataSource.apply(snapshot, to: 0, animatingDifferences: animated)
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
    > { [weak self] cell, indexPath, item in
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

        cell.accessories.append(contentsOf: self?.editor.editingAccessories(for: item) ?? [])
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
    editor.installReordering(on: dataSource, collectionView: collectionView)
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
    applyLibraryItems(animated: false)
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
    // don't allow moving library items in between the fixed items
    editor.targetIndexPath(forProposed: proposedIndexPath, in: dataSource)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    // handel selection
    guard !collectionView.isEditing else {
      collectionView.deselectItem(at: indexPath, animated: true)
      guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
      // toggle in use without moving the item
      editor.toggle(item, in: dataSource)
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
