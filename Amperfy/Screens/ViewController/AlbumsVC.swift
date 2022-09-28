//
//  AlbumsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import CoreData
import AmperfyKit
import PromiseKit

class AlbumsVC: BasicCollectionViewController, UICollectionViewDelegateFlowLayout {

    private var fetchedResultsController: AlbumFetchedResultsController!
    private var sortButton: UIBarButtonItem!
    private var refreshControl: UIRefreshControl?
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    private var filterTitle = "Albums"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albums)

        collectionView.register(UINib(nibName: CommonCollectionSectionHeader.typeName, bundle: .main), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CommonCollectionSectionHeader.typeName)
        collectionView.register(UINib(nibName: AlbumCollectionCell.typeName, bundle: .main), forCellWithReuseIdentifier: AlbumCollectionCell.typeName)
        
        applyFilter()
        configureSearchController(placeholder: "Search in \"\(filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        
        sortButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(sortButtonPressed))
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    func applyFilter() {
        switch displayFilter {
        case .all:
            self.filterTitle = "Albums"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        case .recentlyAdded:
            self.filterTitle = "Recent Albums"
            self.isIndexTitelsHidden = true
            change(sortType: .recentlyAddedIndex)
        case .favorites:
            self.filterTitle = "Favorite Albums"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        }
        self.navigationItem.title = self.filterTitle
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        fetchedResultsController?.clearResults()
        fetchedResultsController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: sortType != .recentlyAddedIndex)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
        fetchedResultsController.fetch()
        collectionView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRightBarButtonItems()
        updateFromRemote()
    }
    
    func updateRightBarButtonItems() {
        if sortType == .recentlyAddedIndex {
            navigationItem.rightBarButtonItems = []
        } else {
            navigationItem.rightBarButtonItems = [sortButton]
        }
    }
    
    func updateFromRemote() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .recentlyAdded:
            firstly {
                AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncLatestLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Recent Albums Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        case .favorites:
            firstly {
                self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Favorite Albums Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        }
    }

    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.numberOfSections
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
        }
    
    override func collectionView(_ collectionView: UICollectionView,
                            viewForSupplementaryElementOfKind kind: String,
                            at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let sectionHeader: CommonCollectionSectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CommonCollectionSectionHeader.typeName, for: indexPath) as! CommonCollectionSectionHeader
        sectionHeader.display(title: sectionTitle(for: indexPath.section))
        
        if indexPath.section == 0 {
            sectionHeader.displayPlayHeader(
                playContextCb: self.handleHeaderPlay,
                with: appDelegate.player,
                shuffleContextCb: self.handleHeaderShuffle)
        }
        return sectionHeader
    }
    
    func sectionTitle(for section: Int) -> String {
        switch sortType {
        case .name:
            return fetchedResultsController.titleForHeader(inSection: section) ?? ""
        case .rating:
            if let sectionNameInitial = fetchedResultsController.titleForHeader(inSection: section), sectionNameInitial != SectionIndexType.noRatingIndexSymbol {
                return "\(sectionNameInitial) Star\(sectionNameInitial != "1" ? "s" : "")"
            } else {
                return "Not rated"
            }
        case .recentlyAddedIndex:
            return fetchedResultsController.titleForHeader(inSection: section) ?? ""
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: AlbumCollectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumCollectionCell.typeName, for: indexPath) as! AlbumCollectionCell
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(container: album, rootView: self)
        return cell
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func indexTitles(for collectionView: UICollectionView) -> [String]? {
        return isIndexTitelsHidden ? nil : fetchedResultsController.sectionIndexTitles
    }
    
    /// UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        let spaceBetweenCells = self.collectionView(collectionView, layout: collectionViewLayout, minimumInteritemSpacingForSectionAt: indexPath.section)
        let availableWidth = collectionView.bounds.size.width - inset.left - inset.right
        let rowCount = (availableWidth) / AlbumCollectionCell.maxWidth
        let count = ceil(rowCount)
        let artworkWidth = (availableWidth - (spaceBetweenCells * (count - 1))) / count
        return CGSize(width: artworkWidth, height: artworkWidth + 45)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if self.collectionView.traitCollection.userInterfaceIdiom == .phone {
            return 8.0
        } else {
            return 16.0
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.collectionView.traitCollection.userInterfaceIdiom == .phone {
            return UIEdgeInsets.init(top: 8, left: 8, bottom: 8, right: 16)
        } else {
            return UIEdgeInsets.init(top: 8, left: 8, bottom: 8, right: 32)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        let  headerTopHeight = section == 0 ? LibraryElementDetailTableHeaderView.frameHeight : 0.0
        switch sortType {
        case .name:
            return CGSize(width: collectionView.bounds.size.width, height: CommonCollectionSectionHeader.frameHeight + headerTopHeight)
        case .rating:
            return CGSize(width: collectionView.bounds.size.width, height: CommonCollectionSectionHeader.frameHeight + headerTopHeight)
        case .recentlyAddedIndex:
            return CGSize(width: collectionView.bounds.size.width, height: headerTopHeight)
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            firstly {
                self.appDelegate.librarySyncer.searchAlbums(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        collectionView.reloadData()
    }
    
    private var displayedSongs: [AbstractPlayable] {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return [] }
        let displayedAlbums = displayedAlbumsMO.compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        displayedAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return songs
    }
    
    private func handleHeaderPlay() -> PlayContext {
        let songs = displayedSongs
        if songs.count > appDelegate.player.maxSongsToAddOnce {
            return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
        } else {
            return PlayContext(name: filterTitle, playables: songs)
        }
    }
    
    private func handleHeaderShuffle() -> PlayContext {
        let songs = displayedSongs
        if songs.count > appDelegate.player.maxSongsToAddOnce {
            return PlayContext(name: filterTitle, playables: songs[randomPick: appDelegate.player.maxSongsToAddOnce])
        } else {
            return PlayContext(name: filterTitle, playables: songs)
        }
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Albums sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.appDelegate.storage.settings.albumsSortSetting = .name
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .rating {
            alert.addAction(UIAlertAction(title: "Sort by rating", style: .default, handler: { _ in
                self.change(sortType: .rating)
                self.appDelegate.storage.settings.albumsSortSetting = .rating
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = sortButton
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
            self.refreshControl?.endRefreshing()
            return
        }
        firstly {
            AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                .syncLatestLibraryElements()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Albums Latest Elements Sync", error: error)
        }.finally {
            self.refreshControl?.endRefreshing()
        }
    }
    
}
