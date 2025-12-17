//
//  AlbumsCollectionVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.06.24.
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

// MARK: - AlbumsCollectionDiffableDataSource

class AlbumsCollectionDiffableDataSource: BasicUICollectionViewDiffableDataSource {
  var vc: AlbumsCollectionVC

  init(
    vc: AlbumsCollectionVC,
    collectionView: UICollectionView,
    cellProvider: @escaping UICollectionViewDiffableDataSource<Int, NSManagedObjectID>.CellProvider
  ) {
    self.vc = vc
    super.init(collectionView: collectionView, cellProvider: cellProvider)
  }

  func getAlbum(at indexPath: IndexPath) -> Album? {
    guard let objectID = itemIdentifier(for: indexPath) else { return nil }
    guard let object = try? appDelegate.storage.main.context.existingObject(with: objectID),
          let albumMO = object as? AlbumMO
    else {
      return nil
    }
    return Album(managedObject: albumMO)
  }

  func getFirstAlbum(in section: Int) -> Album? {
    getAlbum(at: IndexPath(row: 0, section: section))
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    canMoveItemAt indexPath: IndexPath
  )
    -> Bool {
    // reordering/moving is not allowed
    false
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath
  )
    -> UICollectionReusableView {
    guard kind == UICollectionView.elementKindSectionHeader else {
      return UICollectionReusableView()
    }
    let sectionHeader: CommonCollectionSectionHeader = collectionView
      .dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: CommonCollectionSectionHeader.typeName,
        for: indexPath
      ) as! CommonCollectionSectionHeader

    switch vc.common.sortType {
    case .artist, .name:
      sectionHeader
        .display(title: sectionTitleToIndexTitle(sectionName: sectionTitle(for: indexPath.section)))
    case .rating, .year:
      sectionHeader.display(title: sectionTitle(for: indexPath.section))
    case .duration, .newest, .recent:
      sectionHeader.display(title: nil)
    }

    if indexPath.section == 0 {
      sectionHeader.displayPlayHeader(configuration: vc.common.createPlayShuffleInfoConfig())
    }
    return sectionHeader
  }

  override func indexTitles(for collectionView: UICollectionView) -> [String]? {
    switch vc.common.sortType {
    case .artist, .duration, .name, .rating, .year:
      let sectionCount = numberOfSections(in: collectionView)
      var indexTitles = [String]()
      for i in 0 ... sectionCount {
        let sectionName = sectionTitle(for: i)
        indexTitles.append(sectionTitleToIndexTitle(sectionName: sectionName))
      }
      return indexTitles
    case .newest, .recent:
      return nil
    }
  }

  func sectionTitleToIndexTitle(sectionName: String) -> String {
    var indexTitle = ""
    switch vc.common.sortType {
    case .name:
      indexTitle = sectionName.prefix(1).uppercased()
      if let _ = Int(indexTitle) {
        indexTitle = "#"
      }
    case .artist:
      indexTitle = sectionName.prefix(1).uppercased()
      if let _ = Int(indexTitle) {
        indexTitle = "#"
      }
    case .rating:
      indexTitle = IndexHeaderNameGenerator.sortByRating(forSectionName: sectionName)
    case .duration:
      indexTitle = IndexHeaderNameGenerator.sortByDurationAlbum(forSectionName: sectionName)
    case .year:
      indexTitle = IndexHeaderNameGenerator.sortByYear(forSectionName: sectionName)
    default:
      break
    }
    return indexTitle
  }

  func sectionTitle(for section: Int) -> String {
    switch vc.common.sortType {
    case .name:
      guard let album = getFirstAlbum(in: section) else { return "" }
      return album.name
    case .rating:
      guard let album = getFirstAlbum(in: section) else { return "" }
      if album.rating > 0 {
        return "\(album.rating) Star\(album.rating != 1 ? "s" : "")"
      } else {
        return "Not rated"
      }
    case .newest, .recent:
      return ""
    case .artist:
      guard let album = getFirstAlbum(in: section) else { return "" }
      return album.subtitle ?? ""
    case .duration:
      guard let album = getFirstAlbum(in: section) else { return "" }
      return album.duration.description
    case .year:
      let year = getFirstAlbum(in: section)?.year.description
      guard let year = year else { return "" }
      return IndexHeaderNameGenerator.sortByYear(forSectionName: year)
    }
  }
}

// MARK: - AlbumsCollectionVC

class AlbumsCollectionVC: SingleSnapshotFetchedResultsCollectionViewController<AlbumMO> {
  override var sceneTitle: String? {
    common.sceneTitle
  }

  fileprivate var common: AlbumsCommonVCInteractions

  private var previousSize: CGSize = .zero

  public var displayFilter: DisplayCategoryFilter {
    set { common.displayFilter = newValue }
    get { common.displayFilter }
  }

  private var albumsDataSource: AlbumsCollectionDiffableDataSource? {
    diffableDataSource as? AlbumsCollectionDiffableDataSource
  }

  override init(collectionViewLayout: UICollectionViewLayout, account: Account) {
    self.common = AlbumsCommonVCInteractions(account: account)
    super.init(collectionViewLayout: collectionViewLayout, account: account)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func createDiffableDataSource() -> BasicUICollectionViewDiffableDataSource {
    let source = AlbumsCollectionDiffableDataSource(
      vc: self,
      collectionView: collectionView
    ) { collectionView, indexPath, objectID -> UICollectionViewCell? in
      guard let object = try? self.appDelegate.storage.main.context.existingObject(with: objectID),
            let albumMO = object as? AlbumMO
      else {
        fatalError("Managed object should be available")
      }
      let album = Album(managedObject: albumMO)
      return self.createCell(collectionView, forItemAt: indexPath, album: album)
    }
    return source
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // ensures that the collection view stops placing items under the sidebar
    collectionView.contentInsetAdjustmentBehavior = .always

    appDelegate.userStatistics.visited(.albums)

    common.rootVC = self
    common.isIndexTitelsHiddenCB = {
      self.isIndexTitelsHidden = self.common.isIndexTitelsHidden
    }
    common.reloadListViewCB = {
      self.collectionView.reloadData()
    }
    common.updateSearchResultsCB = {
      self.updateSearchResults(for: self.searchController)
    }
    common.endRefreshCB = {
      self.refreshControl?.endRefreshing()
    }
    common.updateFetchDataSourceCB = {
      self.common.fetchedResultsController.delegate = self
    }

    common.applyFilter()
    configureSearchController(
      placeholder: "Search in \"\(common.filterTitle)\"",
      scopeButtonTitles: ["All", "Cached"]
    )
    collectionView.register(
      UINib(nibName: CommonCollectionSectionHeader.typeName, bundle: .main),
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: CommonCollectionSectionHeader.typeName
    )
    collectionView.register(
      UINib(nibName: AlbumCollectionCell.typeName, bundle: .main),
      forCellWithReuseIdentifier: AlbumCollectionCell.typeName
    )

    switch common.sortType {
    case .artist, .duration, .name, .rating, .year:
      collectionView.showsVerticalScrollIndicator = false
    case .newest, .recent:
      collectionView.showsVerticalScrollIndicator = true
    }

    #if !targetEnvironment(macCatalyst)
      refreshControl = UIRefreshControl()
    #endif

    refreshControl?.addTarget(
      common,
      action: #selector(AlbumsCommonVCInteractions.handleRefresh),
      for: UIControl.Event.valueChanged
    )
    collectionView.refreshControl = refreshControl

    containableAtIndexPathCallback = { indexPath in
      self.albumsDataSource?.getAlbum(at: indexPath)
    }
    playContextAtIndexPathCallback = { indexPath in
      guard let album = self.albumsDataSource?.getAlbum(at: indexPath) else { return nil }
      return PlayContext(containable: album)
    }
    snapshotDidChange = {
      self.common.updateContentUnavailable()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    common.updateRightBarButtonItems()
    common.updateFromRemote()
    common.updateContentUnavailable()
  }

  func createCell(
    _ collectionView: UICollectionView,
    forItemAt indexPath: IndexPath,
    album: Album
  )
    -> UICollectionViewCell {
    let cell: AlbumCollectionCell = collectionView.dequeueReusableCell(
      withReuseIdentifier: AlbumCollectionCell.typeName,
      for: indexPath
    ) as! AlbumCollectionCell
    if let album = (diffableDataSource as? AlbumsCollectionDiffableDataSource)?
      .getAlbum(at: indexPath) {
      cell.display(
        container: album,
        rootView: self,
        rootFlowLayout: self,
        initialIndexPath: indexPath
      )
    }
    return cell
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    guard let albumsDataSource = albumsDataSource,
          let album = albumsDataSource.getAlbum(at: indexPath)
    else { return }
    navigationController?.pushViewController(
      AppStoryboard.Main.segueToAlbumDetail(account: account, album: album),
      animated: true
    )
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    common.listViewWillDisplayCell(at: indexPath, searchBarText: searchController.searchBar.text)
  }

  override func indexTitles(for collectionView: UICollectionView) -> [String]? {
    isIndexTitelsHidden ? nil : albumsDataSource?.indexTitles(for: collectionView)
  }

  override func updateSearchResults(for searchController: UISearchController) {
    common.updateSearchResults(for: searchController)
    collectionView.reloadData()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Recalculate the layout when the viewController is resized
    let currentSize = view.bounds.size
    if currentSize != previousSize {
      previousSize = currentSize
      collectionView.collectionViewLayout.invalidateLayout()
    }
  }
}

// MARK: UICollectionViewDelegateFlowLayout

extension AlbumsCollectionVC: UICollectionViewDelegateFlowLayout {
  static let minimumLineSpacing: CGFloat = 16
  static let minimumInteritemSpacing: CGFloat = 16

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  )
    -> CGSize {
    let inset = self.collectionView(
      collectionView,
      layout: collectionViewLayout,
      insetForSectionAt: indexPath.section
    )

    let marginsAndInsets = inset.left + inset.right + collectionView.safeAreaInsets
      .left + collectionView.safeAreaInsets.right + Self
      .minimumInteritemSpacing *
      CGFloat(appDelegate.storage.settings.user.albumsGridSizeSetting - 1)
    let itemWidth =
      (
        (collectionView.bounds.size.width - marginsAndInsets) /
          CGFloat(appDelegate.storage.settings.user.albumsGridSizeSetting)
      ).rounded(.down)
    return CGSize(width: itemWidth, height: itemWidth + 45)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumLineSpacingForSectionAt section: Int
  )
    -> CGFloat {
    Self.minimumLineSpacing
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumInteritemSpacingForSectionAt section: Int
  )
    -> CGFloat {
    Self.minimumInteritemSpacing
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    insetForSectionAt section: Int
  )
    -> UIEdgeInsets {
    if self.collectionView.traitCollection.userInterfaceIdiom == .phone {
      return UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    } else {
      return UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 32)
    }
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    referenceSizeForHeaderInSection section: Int
  )
    -> CGSize {
    let headerTopHeight = section == 0 ? LibraryElementDetailTableHeaderView.frameHeight : 0.0
    switch common.sortType {
    case .artist, .name, .rating, .year:
      return CGSize(
        width: collectionView.bounds.size.width,
        height: CommonCollectionSectionHeader.frameHeight + headerTopHeight
      )
    case .duration, .newest, .recent:
      return CGSize(width: collectionView.bounds.size.width, height: headerTopHeight)
    }
  }
}
