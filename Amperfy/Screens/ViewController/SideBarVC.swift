//
//  SideBarVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.02.24.
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

class Item: Hashable {
    let id = UUID()
    let title: String
    var library: LibraryDisplayType?
    var isSelected = false
    var tab: SideBarItems?
    
    init(title: String, library: LibraryDisplayType? = nil, isSelected: Bool = false, tab: SideBarItems? = nil) {
        self.title = title
        self.library = library
        self.isSelected = isSelected
        self.tab = tab
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Item,
                    rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
}

enum SideBarItems: Int, Hashable, CaseIterable {
    case search
    case settings
    
    static var offset: Int {
        return Self.allCases.count + 1 // add library item too
    }

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
        case .settings: 
            return SettingsHostVC.instantiateFromAppStoryboard()
        }
    }
}

class SideBarDiffableDataSource: UICollectionViewDiffableDataSource<Int, Item> {
    
    override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return (indexPath.row >= SideBarItems.offset)
    }
    
    override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
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

class SideBarVC: UIViewController {
    
    private var data: [Item] = {
        return [Item(title: "Search", tab: .search),
                Item(title: "Settings", tab: .settings),
                Item(title: "Library")]
    }()
    private var editButton: UIBarButtonItem!
    private var librarySettings = LibraryDisplaySettings.defaultSettings
    private var libraryInUse = [Item]()
    private var libraryNotUsed = [Item]()

    static let sectionHeaderElementKind = "section-header-element-kind"

    @IBOutlet private var collectionView: UICollectionView!
    private var dataSource: SideBarDiffableDataSource!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editingPressed))
        navigationItem.rightBarButtonItems = [editButton]
        librarySettings = appDelegate.storage.settings.libraryDisplaySettings
        libraryInUse = librarySettings.inUse.map { Item(title: $0.displayName, library: $0) }
        libraryNotUsed = librarySettings.notUsed.map { Item(title: $0.displayName, library: $0) }
        
        self.collectionView.delegate = self
        self.collectionView.allowsMultipleSelectionDuringEditing = true
        self.collectionView.collectionViewLayout = createLayout() // 1 Configure the layout
        configureDataSource() // 2 configure the data Source
        applyInitialSnapshots() // 3 Apply the snapshots.
    }
    
    @objc private func editingPressed() {
        let isInEditMode = !collectionView.isEditing
        editButton.title = isInEditMode ? "Done" : "Edit"
        editButton.style = isInEditMode ? .done : .plain
        
        if isInEditMode {
            collectionView.isEditing.toggle()
            var snapshot = dataSource.snapshot(for: 0)
            for (index, _) in snapshot.items.enumerated() {
                if index >= SideBarItems.offset {
                    collectionView.selectItem(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .centeredHorizontally)
                }
                
            }
            snapshot.append(libraryNotUsed)
            dataSource.apply(snapshot, to: 0, animatingDifferences: true)
        } else {
            collectionView.isEditing.toggle()
            var snapshot = dataSource.snapshot(for: 0)
            let inUse = snapshot.items.filter({ $0.isSelected && ($0.library != nil)}).compactMap({ $0 })
            struct Temp {
                let indexPath: IndexPath
                let item: Item
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
            let offsetItems = Array(snapshot.items[0...SideBarItems.allCases.count])
            snapshot2.delete(offsetItems)
            snapshot2.delete(libraryInUse)
            libraryNotUsed = snapshot2.items
            snapshot.delete(libraryNotUsed)
            appDelegate.storage.settings.libraryDisplaySettings = LibraryDisplaySettings(inUse: libraryInUse.compactMap({ $0.library }))
            dataSource.apply(snapshot, to: 0, animatingDifferences: true)
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let layoutConfig = UICollectionLayoutListConfiguration(appearance: .sidebar)
            let section = NSCollectionLayoutSection.list(using: layoutConfig, layoutEnvironment: layoutEnvironment)
            let headerFooterSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                         heightDimension: .estimated(0))
            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerFooterSize,
                elementKind: SideBarVC.sectionHeaderElementKind, alignment: .top)
            section.boundarySupplementaryItems = [sectionHeader]
            
            return section
        }
        return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider)
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            
            if item.title == "Library" {
                content.text = item.title
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                cell.accessories = []
            } else if let libraryItem = item.library {
                content.text = libraryItem.displayName
                content.image = libraryItem.image.withRenderingMode(.alwaysTemplate)
                if !libraryItem.image.isSymbolImage {
                    let imageSize = UIImage.symbolImageSize(scale: .large)
                    content.imageProperties.maximumSize = imageSize
                    content.imageProperties.reservedLayoutSize = imageSize
                }
                cell.accessories = [
                    .multiselect(),
                    .disclosureIndicator(displayed: .whenNotEditing),
                    .reorder()]
                cell.isSelected = item.isSelected
            } else if let tabItem = item.tab {
                content.text = tabItem.title
                content.image = tabItem.icon
                cell.accessories = [.disclosureIndicator()]

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
        // data source
        dataSource = SideBarDiffableDataSource(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
                return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        /// 3 - data source supplementaryViewProvider
        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration, for: index)
        }
    }

    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        dataSource.apply(snapshot, animatingDifferences: false)
        
        let libraryItems = librarySettings.inUse.map { Item(title: $0.displayName, library: $0, isSelected: true) }
        data.append(contentsOf: libraryItems)
        
        var outlineSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
        outlineSnapshot.append(data)
        dataSource.apply(outlineSnapshot, to: 0, animatingDifferences: false)
    }

}

extension SideBarVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if collectionView.isEditing {
            return (indexPath.row >= SideBarItems.offset)
        } else if indexPath.row == 2 {
            // library item is not selectable
            return false
        } else {
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canEditItemAt indexPath: IndexPath) -> Bool {
        return collectionView.isEditing
    }
    
    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        if proposedIndexPath.row >= SideBarItems.offset {
            return proposedIndexPath
        } else {
            return IndexPath(row: SideBarItems.offset, section: 0)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        // handel selection
        guard !collectionView.isEditing else {
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
            var snapshot = dataSource.snapshot()
            item.isSelected = true
            snapshot.reloadItems([item])
            dataSource.apply(snapshot, animatingDifferences: true)
            return
        }
        // Retrieve the item identifier using index path.
        // The item identifier we get will be the selected data item
        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        guard let splitVC = self.splitViewController as? SplitVC,
              !splitVC.isCollapsed
        else { return }

        if let libraryItem = selectedItem.library {
            splitVC.setViewController(UINavigationController(rootViewController: libraryItem.controller), for: .secondary)
        } else if let libraryItem = selectedItem.tab {
            if libraryItem == .settings {
                let vc = UINavigationController(rootViewController: libraryItem.controller)
                vc.topViewController?.view.backgroundColor = .secondarySystemBackground
                splitVC.setViewController(vc, for: .secondary)
            } else {
                splitVC.setViewController(UINavigationController(rootViewController: libraryItem.controller), for: .secondary)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didDeselectItemAt indexPath: IndexPath) {
        guard !collectionView.isEditing else {
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
            var snapshot = dataSource.snapshot()
            item.isSelected = false
            snapshot.reloadItems([item])
            dataSource.apply(snapshot, animatingDifferences: true)
            return
        }
    }
}

extension LibraryDisplayType {
    public var controller: UIViewController {
        switch self {
        case .artists:
            return ArtistsVC.instantiateFromAppStoryboard()
        case .albums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            return vc
        case .songs:
            let vc = SongsVC.instantiateFromAppStoryboard()
            return vc
        case .genres:
            let vc = GenresVC.instantiateFromAppStoryboard()
            return vc
        case .directories:
            let vc = MusicFoldersVC.instantiateFromAppStoryboard()
            return vc
        case .playlists:
            let vc = PlaylistsVC.instantiateFromAppStoryboard()
            return vc
        case .podcasts:
            let vc = PodcastsVC.instantiateFromAppStoryboard()
            return vc
        case .downloads:
            let vc = DownloadsVC.instantiateFromAppStoryboard()
            return vc
        case .favoriteSongs:
            let vc = SongsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .favoriteAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .favoriteArtists:
            let vc = ArtistsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .newestAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .newest
            return vc
        case .recentAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .recent
            return vc
        }
    }
}
