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

import UIKit
import AmperfyKit

class LibraryNavigatorItem: Hashable {
    let id = UUID()
    let title: String
    var library: LibraryDisplayType?
    var isSelected = false
    let isInteractable: Bool
    var tab: TabNavigatorItem?
    
    init(title: String, library: LibraryDisplayType? = nil, isSelected: Bool = false, isInteractable: Bool = true, tab: TabNavigatorItem? = nil) {
        self.title = title
        self.library = library
        self.isSelected = isSelected
        self.isInteractable = isInteractable
        self.tab = tab
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LibraryNavigatorItem,
                    rhs: LibraryNavigatorItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum TabNavigatorItem: Int, Hashable, CaseIterable {
    case search
    case settings

    var title: String {
        switch self {
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }
    
    var icon: UIImage {
        switch self {
        case .search: return .search
        case .settings: return .settings
        }
    }
    
    var controller: UIViewController {
        switch self {
        case .search: return SearchVC.instantiateFromAppStoryboard()
        case .settings: return SettingsHostVC.instantiateFromAppStoryboard()
        }
    }
}

typealias SideBarDiffableDataSource = UICollectionViewDiffableDataSource<Int, LibraryNavigatorItem>

class LibraryNavigatorConfigurator: NSObject {
    
    static let sectionHeaderElementKind = "section-header-element-kind"
    
    private var data = [LibraryNavigatorItem]()
    private let offsetData: [LibraryNavigatorItem]
    private var collectionView: UICollectionView!
    private var dataSource: SideBarDiffableDataSource!
    private let layoutConfig: UICollectionLayoutListConfiguration
    private let pressedOnLibraryItemCB: ((_: LibraryNavigatorItem) -> Void)

    #if targetEnvironment(macCatalyst)
    private var preEditItem: LibraryNavigatorItem?
    #endif

    private var editButton: UIBarButtonItem!
    private var librarySettings = LibraryDisplaySettings.defaultSettings
    private var libraryInUse = [LibraryNavigatorItem]()
    private var libraryNotUsed = [LibraryNavigatorItem]()
    
    init(offsetData: [LibraryNavigatorItem], librarySettings: LibraryDisplaySettings, layoutConfig: UICollectionLayoutListConfiguration, pressedOnLibraryItemCB: @escaping ((_: LibraryNavigatorItem) -> Void)) {
        self.offsetData = offsetData
        self.librarySettings = librarySettings
        self.layoutConfig = layoutConfig
        self.pressedOnLibraryItemCB = pressedOnLibraryItemCB
    }
    
    func viewDidLoad(navigationItem: UINavigationItem, collectionView: UICollectionView) {
        self.collectionView = collectionView
        #if !targetEnvironment(macCatalyst)
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editingPressed))
        navigationItem.rightBarButtonItems = [editButton]
        #endif
        libraryInUse = librarySettings.inUse.map { LibraryNavigatorItem(title: $0.displayName, library: $0) }
        libraryNotUsed = librarySettings.notUsed.map { LibraryNavigatorItem(title: $0.displayName, library: $0) }
        self.collectionView.delegate = self
        self.collectionView.collectionViewLayout = createLayout() // 1 Configure the layout
        configureDataSource() // 2 configure the data Source
        applyInitialSnapshots() // 3 Apply the snapshots.
    }

    func viewDidAppear(navigationItem: UINavigationItem, collectionView: UICollectionView) {
        #if targetEnvironment(macCatalyst)
        if self.collectionView.indexPathsForSelectedItems?.first == nil {
            self.collectionView.selectItem(at: .zero, animated: false, scrollPosition: .top)
        }
        #endif
    }

    @objc private func editingPressed() {
        let isInEditMode = !collectionView.isEditing
        #if !targetEnvironment(macCatalyst)
        editButton.title = isInEditMode ? "Done" : "Edit"
        editButton.style = isInEditMode ? .done : .plain
        #endif


        if isInEditMode {
            #if targetEnvironment(macCatalyst)
            let selectedIndexPath = self.collectionView.indexPathsForSelectedItems?.first ?? .zero
            preEditItem = self.dataSource.itemIdentifier(for: selectedIndexPath)
            #endif

            collectionView.isEditing.toggle()
            var snapshot = dataSource.snapshot(for: 0)
            snapshot.append(libraryNotUsed)
            dataSource.apply(snapshot, to: 0, animatingDifferences: true)
        } else {
            collectionView.isEditing.toggle()
            var snapshot = dataSource.snapshot(for: 0)
            let inUse = snapshot.items.filter({ $0.isSelected && ($0.library != nil)}).compactMap({ $0 })
            struct Temp {
                let indexPath: IndexPath
                let item: LibraryNavigatorItem
            }
            let inUseItems = inUse.compactMap({
                if let indexPath = dataSource.indexPath(for: $0) {
                    return Temp(indexPath: indexPath, item: $0)
                } else {
                    return nil
                }
            })
            .sorted(by: { $0.indexPath < $1.indexPath })
            .compactMap({ $0.item })
            libraryInUse = inUseItems
            
            var snapshot2 = dataSource.snapshot(for: 0)
            if !offsetData.isEmpty {
                let offsetItems = Array(snapshot.items[0...(offsetData.count-1)])
                snapshot2.delete(offsetItems)
            }
            snapshot2.delete(libraryInUse)
            libraryNotUsed = snapshot2.items
            snapshot.delete(libraryNotUsed)
            appDelegate.storage.settings.libraryDisplaySettings = LibraryDisplaySettings(inUse: libraryInUse.compactMap({ $0.library }))
            dataSource.apply(snapshot, to: 0, animatingDifferences: true)

            // Restore selection after editing endet on macOS
            #if targetEnvironment(macCatalyst)
            let indexPath = self.preEditItem != nil ? self.dataSource.indexPath(for: preEditItem!) : .zero
            self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
            #endif
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let section = NSCollectionLayoutSection.list(using: self.layoutConfig, layoutEnvironment: layoutEnvironment)
            let headerFooterSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                          heightDimension: .estimated(.leastNonzeroMagnitude))
            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerFooterSize,
                elementKind: Self.sectionHeaderElementKind, alignment: .top)
            section.boundarySupplementaryItems = [sectionHeader]
            
            return section
        }
        return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider)
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, LibraryNavigatorItem> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            
            if !item.isInteractable {
                content.text = item.title
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                #if targetEnvironment(macCatalyst)
                // show edit on the right-hand side of the header
                cell.accessories = [
                    .customView(configuration: .createEdit(target: self, action: #selector(self.editingPressed))),
                    .customView(configuration: .createDone(target: self, action: #selector(self.editingPressed)))
                ]
                #else
                cell.accessories = []
                #endif
            } else if let libraryItem = item.library {
                content.text = libraryItem.displayName
                content.image = libraryItem.image.withRenderingMode(.alwaysTemplate)
                var imageSize = CGSize(width: 35.0, height: 25.0)
                if !libraryItem.image.isSymbolImage {
                    // special case for podcast icon
                    imageSize = CGSize(width: imageSize.width, height: imageSize.height-2)
                }
                content.imageProperties.maximumSize = imageSize
                content.imageProperties.reservedLayoutSize = imageSize
                #if targetEnvironment(macCatalyst)
                cell.accessories = [.reorder()]
                #else
                cell.accessories = [.disclosureIndicator(displayed: .whenNotEditing), .reorder()]
                #endif
                if item.isSelected {
                    cell.accessories.append(.customView(configuration: .createIsSelected()))
                } else {
                    cell.accessories.append(.customView(configuration: .createUnSelected()))
                }
            } else if let tabItem = item.tab {
                content.text = tabItem.title
                content.image = tabItem.icon
                #if targetEnvironment(macCatalyst)
                cell.accessories = []
                #else
                cell.accessories = [.disclosureIndicator()]
                #endif
            }
            cell.contentConfiguration = content
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
            (collectionView, indexPath, item) -> UICollectionViewCell? in
                return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        /// 3 - data source supplementaryViewProvider
        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: index)
        }

        /// 4 - data source reordering
        dataSource.reorderingHandlers.canReorderItem = { [weak self] item in
            let isEdit = self?.collectionView.isEditing ?? false
            return isEdit && (item.tab == nil)
        }

        // Somehow, this fixes a crash when trying to reorder the sidebar in catalyst. Leave it in.
        #if targetEnvironment(macCatalyst)
        dataSource.reorderingHandlers.didReorder = { _ in }
        #endif
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, LibraryNavigatorItem>()
        snapshot.appendSections([0])
        dataSource.apply(snapshot, animatingDifferences: false)
        
        data.append(contentsOf: offsetData)
        let libraryItems = librarySettings.inUse.map { LibraryNavigatorItem(title: $0.displayName, library: $0, isSelected: true) }
        data.append(contentsOf: libraryItems)
        
        var outlineSnapshot = NSDiffableDataSourceSectionSnapshot<LibraryNavigatorItem>()
        outlineSnapshot.append(data)
        dataSource.apply(outlineSnapshot, to: 0, animatingDifferences: false)
    }
    
}

extension LibraryNavigatorConfigurator: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if collectionView.isEditing {
            return (indexPath.row >= offsetData.count)
        } else if let item = dataSource.itemIdentifier(for: indexPath) {
            #if targetEnvironment(macCatalyst)
            // Do not allow reselecting an already selected cell
            guard let alreadySelected = collectionView.indexPathsForSelectedItems?.contains(indexPath), !alreadySelected else {
                return false
            }
            #endif
            return item.isInteractable
        } else {
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canEditItemAt indexPath: IndexPath) -> Bool {
        return collectionView.isEditing
    }
    
    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        if proposedIndexPath.row >= offsetData.count {
            return proposedIndexPath
        } else {
            return IndexPath(row: offsetData.count, section: 0)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        // handel selection
        guard !collectionView.isEditing else {
            collectionView.deselectItem(at: indexPath, animated: true)
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
            var snapshot = dataSource.snapshot()
            item.isSelected.toggle()
            snapshot.reconfigureItems([item])
            dataSource.apply(snapshot, animatingDifferences: false)
            return
        }
        // Retrieve the item identifier using index path.
        // The item identifier we get will be the selected data item

        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else {
            #if !targetEnvironment(macCatalyst)
            collectionView.deselectItem(at: indexPath, animated: true)
            #endif
            return
        }

        #if !targetEnvironment(macCatalyst)
        collectionView.deselectItem(at: indexPath, animated: false)
        #endif

        pressedOnLibraryItemCB(selectedItem)
    }
}


extension IndexPath {
    static let zero = IndexPath(row: 0, section: 0)
}
