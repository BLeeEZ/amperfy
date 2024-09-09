//
//  AlbumsCommonVCInteractions.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 20.06.24.
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
import CoreData
import AmperfyKit
import PromiseKit

class SliderMenuPopover: UIViewController, UIPopoverPresentationControllerDelegate {
    var sliderMenuView: SliderMenuView {
        self.view as! SliderMenuView
    }

    override func loadView() {
        self.view = SliderMenuView()
    }

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class SliderMenuView: UIView {
    
    let slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    var stepValue: Float = 1.0
    var sliderValueChangedCB: VoidFunctionCallback?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(slider)
        slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
        slider.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        let newStep = roundf(slider.value / self.stepValue)
        self.slider.value = newStep * self.stepValue;
        sliderValueChangedCB?()
    }
}

class AlbumsCommonVCInteractions {
    
    var sceneTitle: String? {
        return switch (self.displayFilter) {
        case .all: "Albums"
        case .newest: "Newest Albums"
        case .recent: "Recently Played Albums"
        case .favorites: "Favorite Albums"
        }
    }

    public var isIndexTitelsHiddenCB: VoidFunctionCallback?
    public var reloadListViewCB: VoidFunctionCallback?
    public var updateSearchResultsCB: VoidFunctionCallback?
    public var endRefreshCB: VoidFunctionCallback?
    public var updateFetchDataSourceCB: VoidFunctionCallback?

    private var appDelegate: AppDelegate = (UIApplication.shared.delegate as! AppDelegate)

    public var rootVC: UIViewController?
    public var fetchedResultsController: AlbumFetchedResultsController!
    public var optionsButton: UIBarButtonItem = OptionsBarButton()
    public var displayFilter: DisplayCategoryFilter = .all
    public var sortType: AlbumElementSortType = .name
    public var filterTitle = "Albums"
    public var newestElementsOffsetsSynced = Set<Int>()
    public var isIndexTitelsHidden = false {
        didSet {
            isIndexTitelsHiddenCB?()
        }
    }
    
    func applyFilter() {
        switch displayFilter {
        case .all:
            self.filterTitle = "Albums"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        case .newest:
            self.filterTitle = "Newest Albums"
            self.isIndexTitelsHidden = true
            change(sortType: .newest)
        case .recent:
            self.filterTitle = "Recently Played Albums"
            self.isIndexTitelsHidden = true
            change(sortType: .recent)
        case .favorites:
            self.filterTitle = "Favorite Albums"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        }
        rootVC?.setNavBarTitle(title: self.filterTitle)
    }

    func change(sortType: AlbumElementSortType) {
        self.sortType = sortType
        fetchedResultsController?.clearResults()
        var isGroupedInAlphabeticSections = false
        switch sortType {
        case .name, .rating, .artist, .duration, .year:
            isGroupedInAlphabeticSections = true
        case .newest, .recent:
            isGroupedInAlphabeticSections = false
        }
        
        fetchedResultsController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
        updateFetchDataSourceCB?()
        fetchedResultsController.fetch()
        updateRightBarButtonItems()
    }
    
    func listViewWillDisplayCell(at indexPath: IndexPath, searchBarText: String?) {
        guard let elementCount = fetchedResultsController.fetchResultsController.fetchedObjects?.count else { return}
        if sortType == .newest || sortType == .recent,
           (searchBarText ?? "").isEmpty,
           indexPath.row > 0,
           // fetch each 20th row or on last element
           indexPath.row == elementCount-1 || (indexPath.row % 20 == 0),
           // this offset has not been synced yet
           !newestElementsOffsetsSynced.contains(indexPath.row) {
            newestElementsOffsetsSynced.insert(indexPath.row)
            updateFromRemote(offset: indexPath.row, count: AmperKit.newestElementsFetchCount)
        }
    }
    
    func updateFromRemote(offset: Int = 0, count: Int = AmperKit.newestElementsFetchCount) {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .newest:
            firstly {
                AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncNewestLibraryElements(offset: offset, count: count)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Newest Albums Sync", error: error)
            }.finally {
                self.updateSearchResultsCB?()
            }
        case .recent:
            firstly {
                self.appDelegate.librarySyncer.syncRecentAlbums(offset: offset, count: count)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Recent Albums Sync", error: error)
            }.finally {
                self.updateSearchResultsCB?()
            }
        case .favorites:
            firstly {
                self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Favorite Albums Sync", error: error)
            }.finally {
                self.updateSearchResultsCB?()
            }
        }
    }
    
    func updateRightBarButtonItems() {
        var actions = [UIMenu]()

        switch sortType {
        case .name, .rating, .artist, .duration, .year:
            actions.append(createSortButtonMenu())
        case .newest, .recent:
            break
        }
        actions.append(createStyleButtonMenu())

        if appDelegate.storage.settings.isOnlineMode {
            actions.append(createActionButtonMenu())
        }
            
        if !actions.isEmpty {
            optionsButton.menu = UIMenu(children: actions)
            rootVC?.navigationItem.rightBarButtonItems = [optionsButton]
        } else {
            rootVC?.navigationItem.rightBarButtonItems = []
        }
    }
    
    private func createSortButtonMenu() -> UIMenu {
        let sortByName = UIAction(title: "Name", image: sortType == .name ? .check : nil, handler: { _ in
            self.change(sortType: .name)
            self.appDelegate.storage.settings.albumsSortSetting = .name
            self.updateSearchResultsCB?()
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByRating = UIAction(title: "Rating", image: sortType == .rating ? .check : nil, handler: { _ in
            self.change(sortType: .rating)
            self.appDelegate.storage.settings.albumsSortSetting = .rating
            self.updateSearchResultsCB?()
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByArtist = UIAction(title: "Artist", image: sortType == .artist ? .check : nil, handler: { _ in
            self.change(sortType: .artist)
            self.appDelegate.storage.settings.albumsSortSetting = .artist
            self.updateSearchResultsCB?()
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByDuration = UIAction(title: "Duration", image: sortType == .duration ? .check : nil, handler: { _ in
            self.change(sortType: .duration)
            self.appDelegate.storage.settings.albumsSortSetting = .duration
            self.updateSearchResultsCB?()
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByYear = UIAction(title: "Year", image: sortType == .year ? .check : nil, handler: { _ in
            self.change(sortType: .year)
            self.appDelegate.storage.settings.albumsSortSetting = .year
            self.updateSearchResultsCB?()
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        return UIMenu(title: "Sort", image: .sort, options: [], children: [sortByName, sortByRating, sortByArtist, sortByDuration, sortByYear])
    }
    
    func showSliderMenu() {
        guard let rootVC = rootVC else { return }

        let popoverContentController = SliderMenuPopover()
        let sliderMenuView = popoverContentController.sliderMenuView
        sliderMenuView.frame = CGRect(x: 0, y: 0, width: 250, height: 50)

        if UIDevice.current.userInterfaceIdiom == .mac {
            sliderMenuView.slider.minimumValue = 3
            sliderMenuView.slider.maximumValue = 7
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            sliderMenuView.slider.minimumValue = 3
            sliderMenuView.slider.maximumValue = 7
        } else {
            sliderMenuView.slider.minimumValue = 2
            sliderMenuView.slider.maximumValue = 5
        }
        sliderMenuView.slider.value = min(max(
            sliderMenuView.slider.minimumValue,
            Float(self.appDelegate.storage.settings.albumsGridSizeSetting)),
            sliderMenuView.slider.maximumValue)
        sliderMenuView.sliderValueChangedCB = {
            let newIntValue = Int( sliderMenuView.slider.value )
            if newIntValue != self.appDelegate.storage.settings.albumsGridSizeSetting {
                self.appDelegate.storage.settings.albumsGridSizeSetting = newIntValue
                if let collectionVC = rootVC as? AlbumsCollectionVC {
                    collectionVC.collectionView.reloadData()
                }
            }
        }


        popoverContentController.modalPresentationStyle = .popover
        popoverContentController.preferredContentSize = sliderMenuView.frame.size

        if let popoverPresentationController = popoverContentController.popoverPresentationController {
            popoverPresentationController.permittedArrowDirections = .up
            popoverPresentationController.delegate = popoverContentController
            // Try to position the popover more nicely and fallback to the default if it does not work
            if let optionsView = optionsButton.customView {
                popoverPresentationController.sourceView = optionsView
                var frame = optionsView.bounds
                frame.origin.x = optionsView.frame.midX - 3
                popoverPresentationController.sourceRect = frame
            } else {
                popoverPresentationController.barButtonItem = optionsButton
            }
            rootVC.present(popoverContentController, animated: true, completion: nil)
        }
     }
    
    private func createStyleButtonMenu() -> UIMenu {
        let tableStyle = UIAction(title: "Table", image: self.appDelegate.storage.settings.albumsStyleSetting == .table ? .check : nil, handler: { _ in
            self.appDelegate.storage.settings.albumsStyleSetting = .table
            self.rootVC?.navigationController?.replaceCurrentlyActiveVC(with: AppStoryboard.Main.createAlbumsVC(style: self.appDelegate.storage.settings.albumsStyleSetting, category: self.displayFilter), animated: false)
        })
        let gridStyle = UIAction(title: "Grid", image: self.appDelegate.storage.settings.albumsStyleSetting == .grid ? .check : nil, handler: { _ in
            self.appDelegate.storage.settings.albumsStyleSetting = .grid
            self.rootVC?.navigationController?.replaceCurrentlyActiveVC(with: AppStoryboard.Main.createAlbumsVC(style: self.appDelegate.storage.settings.albumsStyleSetting, category: self.displayFilter), animated: false)
        })
        let changeGridSize = UIAction(title: "Change Grid Size", image: .resize, handler: { _ in
            self.showSliderMenu()
        })
        changeGridSize.attributes = (self.appDelegate.storage.settings.albumsStyleSetting != .grid) ? .disabled : []
        
        return UIMenu(title: "Style", image: .grid, options: [], children: [tableStyle, gridStyle, changeGridSize])
    }
    
    private func createActionButtonMenu() -> UIMenu {
        let action = UIAction(title: "Download \(filterTitle)", image: UIImage.startDownload, handler: { _ in
            var albums = [Album]()
            switch self.displayFilter {
            case .all:
                albums = self.appDelegate.storage.main.library.getAlbums()
            case .newest:
                albums = self.appDelegate.storage.main.library.getNewestAlbums()
            case .recent:
                albums = self.appDelegate.storage.main.library.getRecentAlbums()
            case .favorites:
                albums = self.appDelegate.storage.main.library.getFavoriteAlbums()
            }
            let albumSongs = Array(albums.compactMap{ $0.playables }.joined())
            if albumSongs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
                let alert = UIAlertController(title: "Many Songs", message: "Are you shure to add \(albumSongs.count) songs from \"\(self.filterTitle)\" to download queue?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.appDelegate.playableDownloadManager.download(objects: albumSongs)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.rootVC?.present(alert, animated: true, completion: nil)
            } else {
                self.appDelegate.playableDownloadManager.download(objects: albumSongs)
            }
        })
        return UIMenu(options: [.displayInline], children: [action])
    }
    
    private var displayedSongs: [AbstractPlayable] {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return [] }
        let displayedAlbums = displayedAlbumsMO.compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        displayedAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return songs
    }
    
    public func handleHeaderPlay() -> PlayContext {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        let firstAlbums = displayedAlbumsMO.prefix(5).compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        firstAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
    }
    
    public func handleHeaderShuffle() -> PlayContext {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        let randomAlbums = displayedAlbumsMO[randomPick: 5].compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        randomAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
           firstly {
               self.appDelegate.librarySyncer.searchAlbums(searchText: searchText)
           }.catch { error in
               self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
    }
    
    func createPlayShuffleInfoConfig() -> PlayShuffleInfoConfiguration {
       return PlayShuffleInfoConfiguration(
            infoCB: { "\(self.fetchedResultsController.fetchedObjects?.count ?? 0) Album\((self.fetchedResultsController.fetchedObjects?.count ?? 0) == 1 ? "" : "s")" },
            playContextCb: self.handleHeaderPlay,
            player: appDelegate.player,
            isInfoAlwaysHidden: false,
            isShuffleOnContextNeccessary: false,
            shuffleContextCb: self.handleHeaderShuffle)
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
            endRefreshCB?()
            return
        }
        firstly {
            if self.displayFilter == .recent {
                return self.appDelegate.librarySyncer.syncRecentAlbums(offset: 0, count: AmperKit.newestElementsFetchCount)
            } else {
                return AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncNewestLibraryElements()
            }
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Albums Newest Elements Sync", error: error)
        }.finally {
            self.endRefreshCB?()
        }
    }
}
