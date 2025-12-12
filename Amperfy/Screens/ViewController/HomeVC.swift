//
//  HomeVC.swift
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
import CoreData
import OSLog
import UIKit

// MARK: - HomeVC

final class HomeVC: UICollectionViewController {
  // MARK: - Types

  struct Item: Hashable, @unchecked Sendable {
    let id = UUID()
    var playableContainable: PlayableContainable

    static func == (lhs: HomeVC.Item, rhs: HomeVC.Item) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
  }

  // MARK: - Properties

  private var data: [HomeSection: [Item]] = [:]
  private var dataSource: UICollectionViewDiffableDataSource<HomeSection, Item>!
  private let log = OSLog(subsystem: "Amperfy", category: "HomeVC")

  private static let itemWidth: CGFloat = 160.0
  private static let sectionMaxItemCount = 20

  private var albumsRecentFetchController: AlbumFetchedResultsController?
  private var albumsLatestFetchController: AlbumFetchedResultsController?
  private var playlistsLastTimePlayedFetchController: PlaylistFetchedResultsController?
  private var podcastEpisodesFetchedController: PodcastEpisodesReleaseDateFetchedResultsController?
  private var podcastsFetchedController: PodcastFetchedResultsController?
  private var radiosFetchedController: RadiosFetchedResultsController?

  private var orderedVisibleSections: [HomeSection]!

  private var userButton: UIButton?
  private var userBarButtonItem: UIBarButtonItem?

  // MARK: - Init

  init() {
    let layout = HomeVC.createLayout()
    super.init(collectionViewLayout: layout)
  }

  required init?(coder: NSCoder) {
    let layout = HomeVC.createLayout()
    super.init(collectionViewLayout: layout)
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    orderedVisibleSections = appDelegate.storage.settings.accounts.activeSettings.read.homeSections
    // ensures that the collection view stops placing items under the sidebar
    collectionView.contentInsetAdjustmentBehavior = .scrollableAxes
    title = "Home"

    setupUserNavButton()

    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Edit",
      style: .plain,
      target: self,
      action: #selector(editSectionsTapped)
    )
    configureCollectionView()
    configureDataSource()
    createFetchController()
    applySnapshot(animated: false)

    appDelegate.notificationHandler.register(
      self,
      selector: #selector(refreshOfflineMode),
      name: .offlineModeChanged,
      object: nil
    )
  }

  private func setupUserNavButton() {
    let image = UIImage.userCircle(withConfiguration: UIImage.SymbolConfiguration(
      pointSize: 24,
      weight: .regular
    )).withTintColor(
      appDelegate.storage.settings.accounts.activeSettings.read.themePreference.asColor,
      renderingMode: .alwaysTemplate
    )

    let button = UIButton(type: .system)
    button.setImage(image, for: .normal)
    button.layer.cornerRadius = 20
    button.clipsToBounds = true
    #if targetEnvironment(macCatalyst)
      button.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    #else
      button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    #endif
    button.menu = createUserButtonMenu()
    button.showsMenuAsPrimaryAction = true
    userButton = button

    userBarButtonItem = UIBarButtonItem(customView: button)
    navigationItem.leftBarButtonItem = userBarButtonItem!
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
    updateFromRemote()
  }

  private func createUserButtonMenu() -> UIMenu {
    let userInfo = UIAction(
      title: appDelegate.storage.settings.accounts.activeSettings.read.loginCredentials?
        .username ?? "Unknown",
      subtitle: appDelegate.storage.settings.accounts.activeSettings.read.loginCredentials?
        .displayServerUrl ?? "",
      image: .userCircle(withConfiguration: UIImage.SymbolConfiguration(
        pointSize: 30,
        weight: .regular
      )),
      attributes: [UIMenuElement.Attributes.disabled],
      state: .on,
      handler: { _ in }
    )
    let openSettings = UIAction(
      title: "Settings",
      image: .settings,
      handler: { _ in
        #if targetEnvironment(macCatalyst)
          self.appDelegate.showSettings(sender: "")
        #else
          let nav = AppStoryboard.Main.segueToSettings()
          nav.modalPresentationStyle = .formSheet
          self.present(nav, animated: true)
        #endif
      }
    )

    let settingsMenu = UIMenu(options: [.displayInline], children: [openSettings])

    return UIMenu(
      title: "",
      image: nil,
      options: [.displayInline],
      children: [userInfo, settingsMenu]
    )
  }

  // MARK: - Layout

  private static func createLayout() -> UICollectionViewCompositionalLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
      guard let _ = HomeSection(rawValue: sectionIndex) else { return nil }

      // Item: square image with title below -> estimate height accommodates label
      let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .fractionalHeight(1.0)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemSize)

      // Group: fixed width to show large image; height estimated to fit image + label
      // We'll use a vertical group containing the cell's content; the cell itself handles layout.
      let groupSize = NSCollectionLayoutSize(
        widthDimension: .absolute(itemWidth),
        heightDimension: .estimated(210)
      )
      let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

      let sectionLayout = NSCollectionLayoutSection(group: group)
      sectionLayout.orthogonalScrollingBehavior = .continuous
      sectionLayout.interGroupSpacing = 12
      sectionLayout.contentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 16,
        bottom: 24,
        trailing: 16
      )

      // Header
      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(44)
      )
      let header = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: UICollectionView.elementKindSectionHeader,
        alignment: .top
      )
      header.pinToVisibleBounds = false
      header.zIndex = 1
      sectionLayout.boundarySupplementaryItems = [header]

      return sectionLayout
    }
    return layout
  }

  // MARK: - CollectionView Setup

  private func configureCollectionView() {
    collectionView.backgroundColor = .systemBackground
    collectionView.register(
      UINib(nibName: AlbumCollectionCell.typeName, bundle: .main),
      forCellWithReuseIdentifier: AlbumCollectionCell.typeName
    )
    collectionView.register(
      SectionHeaderView.self,
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: SectionHeaderView.reuseID
    )
  }

  // MARK: - Data Source

  private func configureDataSource() {
    dataSource = UICollectionViewDiffableDataSource<
      HomeSection,
      Item
    >(collectionView: collectionView) { collectionView, indexPath, item in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: AlbumCollectionCell.typeName,
        for: indexPath
      ) as! AlbumCollectionCell
      cell.display(
        container: item.playableContainable,
        rootView: self,
        itemWidth: Self.itemWidth,
        initialIndexPath: indexPath
      )
      return cell
    }

    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
      guard kind == UICollectionView.elementKindSectionHeader,
            let header = collectionView.dequeueReusableSupplementaryView(
              ofKind: kind,
              withReuseIdentifier: SectionHeaderView.reuseID,
              for: indexPath
            ) as? SectionHeaderView,
            let section = self.orderedVisibleSections.element(at: indexPath.section) else {
        return nil
      }
      header.title = section.title
      if section == .randomAlbums {
        header.showsRefreshButton = true
        header.setRefreshHandler { [weak self] in self?.refreshRandomAlbumsSection() }
      } else if section == .randomArtists {
        header.showsRefreshButton = true
        header.setRefreshHandler { [weak self] in self?.refreshRandomArtistsSection() }
      } else if section == .randomGenres {
        header.showsRefreshButton = true
        header.setRefreshHandler { [weak self] in self?.refreshRandomGenresSection() }
      } else if section == .randomSongs {
        header.showsRefreshButton = true
        header.setRefreshHandler { [weak self] in self?.refreshRandomSongsSection() }
      } else {
        header.showsRefreshButton = false
        header.setRefreshHandler(nil)
      }
      return header
    }
  }

  private func applySnapshot(animated: Bool = true) {
    var snapshot = NSDiffableDataSourceSnapshot<HomeSection, Item>()
    snapshot.appendSections(orderedVisibleSections)
    for section in orderedVisibleSections {
      let items = data[section] ?? []
      snapshot.appendItems(items, toSection: section)
    }
    dataSource.apply(snapshot, animatingDifferences: animated)
  }

  var isOfflineMode: Bool {
    appDelegate.storage.settings.user.isOfflineMode
  }

  @objc
  private func refreshOfflineMode() {
    os_log("HomeVC: OfflineModeChanged", log: self.log, type: .info)
    createFetchController()
  }

  func createFetchController() {
    if orderedVisibleSections.contains(where: { $0 == .recentAlbums }) {
      albumsRecentFetchController = AlbumFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        sortType: .recent,
        isGroupedInAlphabeticSections: false,
        fetchLimit: Self.sectionMaxItemCount
      )
      albumsRecentFetchController?.delegate = self
      albumsRecentFetchController?.search(
        searchText: "",
        onlyCached: isOfflineMode,
        displayFilter: .recent
      )
      updateAlbumsRecent()
    } else {
      albumsRecentFetchController?.delegate = nil
      albumsRecentFetchController = nil
    }

    if orderedVisibleSections.contains(where: { $0 == .latestAlbums }) {
      albumsLatestFetchController = AlbumFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        sortType: .recent,
        isGroupedInAlphabeticSections: false,
        fetchLimit: Self.sectionMaxItemCount
      )
      albumsLatestFetchController?.delegate = self
      albumsLatestFetchController?.search(
        searchText: "",
        onlyCached: isOfflineMode,
        displayFilter: .newest
      )
      updateAlbumsLatest()
    } else {
      albumsLatestFetchController?.delegate = nil
      albumsLatestFetchController = nil
    }

    if orderedVisibleSections.contains(where: { $0 == .randomAlbums }) {
      updateRandomAlbums(isOfflineMode: isOfflineMode)
    }
    if orderedVisibleSections.contains(where: { $0 == .randomArtists }) {
      updateRandomArtists(isOfflineMode: isOfflineMode)
    }
    if orderedVisibleSections.contains(where: { $0 == .randomGenres }) {
      updateRandomGenres()
    }
    if orderedVisibleSections.contains(where: { $0 == .randomSongs }) {
      updateRandomSongs(isOfflineMode: isOfflineMode)
    }

    if orderedVisibleSections.contains(where: { $0 == .lastTimePlayedPlaylists }) {
      playlistsLastTimePlayedFetchController = PlaylistFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        sortType: .lastPlayed,
        isGroupedInAlphabeticSections: false,
        fetchLimit: Self.sectionMaxItemCount
      )
      playlistsLastTimePlayedFetchController?.delegate = self
      playlistsLastTimePlayedFetchController?.search(
        searchText: "",
        playlistSearchCategory: isOfflineMode ? .cached : .all
      )
      updatePlaylistsLastTimePlayed()
    } else {
      playlistsLastTimePlayedFetchController?.delegate = nil
      playlistsLastTimePlayedFetchController = nil
    }

    if orderedVisibleSections.contains(where: { $0 == .latestPodcastEpisodes }) {
      podcastEpisodesFetchedController = PodcastEpisodesReleaseDateFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        isGroupedInAlphabeticSections: false,
        fetchLimit: Self.sectionMaxItemCount
      )
      podcastEpisodesFetchedController?.delegate = self
      podcastEpisodesFetchedController?.search(searchText: "", onlyCachedSongs: isOfflineMode)
      updatePodcastEpisodesLatest()
    } else {
      podcastEpisodesFetchedController?.delegate = nil
      podcastEpisodesFetchedController = nil
    }

    if orderedVisibleSections.contains(where: { $0 == .podcasts }) {
      podcastsFetchedController = PodcastFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        isGroupedInAlphabeticSections: false
      )
      podcastsFetchedController?.delegate = self
      podcastsFetchedController?.search(searchText: "", onlyCached: isOfflineMode)
      updatePodcasts()
    } else {
      podcastsFetchedController?.delegate = nil
      podcastsFetchedController = nil
    }

    if orderedVisibleSections.contains(where: { $0 == .radios }) {
      radiosFetchedController = RadiosFetchedResultsController(
        coreDataCompanion: appDelegate.storage.main, account: appDelegate.account,
        isGroupedInAlphabeticSections: true
      )
      radiosFetchedController?.delegate = self
      radiosFetchedController?.fetch()
      updateRadios()
    } else {
      radiosFetchedController?.delegate = nil
      radiosFetchedController = nil
    }
  }

  func updateFromRemote() {
    guard appDelegate.storage.settings.user.isOnlineMode else { return }
    if orderedVisibleSections.contains(where: { $0 == .latestAlbums }) {
      Task { @MainActor in
        do {
          try await AutoDownloadLibrarySyncer(
            storage: self.appDelegate.storage,
            account: self.appDelegate.account,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
          .syncNewestLibraryElements(offset: 0, count: Self.sectionMaxItemCount)
        } catch {
          self.appDelegate.eventLogger.report(topic: "Newest Albums Sync", error: error)
        }
      }
    }
    if orderedVisibleSections.contains(where: { $0 == .recentAlbums }) {
      Task { @MainActor in
        do {
          try await self.appDelegate.librarySyncer.syncRecentAlbums(
            offset: 0,
            count: Self.sectionMaxItemCount
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Recent Albums Sync", error: error)
        }
      }
    }
    if orderedVisibleSections.contains(where: { $0 == .lastTimePlayedPlaylists }) {
      Task { @MainActor in do {
        try await self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Playlists Sync", error: error)
      }}
    }
    if orderedVisibleSections.contains(where: { $0 == .latestPodcastEpisodes }) {
      Task { @MainActor in do {
        let _ = try await AutoDownloadLibrarySyncer(
          storage: self.appDelegate.storage,
          account: self.appDelegate.account,
          librarySyncer: self.appDelegate.librarySyncer,
          playableDownloadManager: self.appDelegate
            .playableDownloadManager
        )
        .syncNewestPodcastEpisodes()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Podcasts Sync", error: error)
      }}
    }
    if orderedVisibleSections.contains(where: { $0 == .radios }) {
      Task { @MainActor in
        do {
          try await self.appDelegate.librarySyncer.syncRadios()
        } catch {
          self.appDelegate.eventLogger.report(topic: "Radios Sync", error: error)
        }
      }
    }
  }

  @objc
  private func editSectionsTapped() {
    presentSectionEditor()
  }

  private func presentSectionEditor() {
    // Build a simple editor using a temporary UIViewController with a table view
    let editor = HomeEditorVC(current: orderedVisibleSections) { [weak self] newOrder in
      guard let self else { return }
      orderedVisibleSections = newOrder
      if let accountInfo = appDelegate.storage.settings.accounts.active {
        appDelegate.storage.settings.accounts.updateSetting(accountInfo) { accountSettings in
          accountSettings.homeSections = newOrder
        }
      }
      applySnapshot(animated: true)

      createFetchController()
      updateFromRemote()
    }
    let nav = UINavigationController(rootViewController: editor)
    nav.modalPresentationStyle = .formSheet
    present(nav, animated: true)
  }

  @objc
  func refreshRandomAlbumsSection() {
    updateRandomAlbums(isOfflineMode: isOfflineMode)
  }

  @objc
  func refreshRandomArtistsSection() {
    updateRandomArtists(isOfflineMode: isOfflineMode)
  }

  @objc
  func refreshRandomGenresSection() {
    updateRandomGenres()
  }

  @objc
  func refreshRandomSongsSection() {
    updateRandomSongs(isOfflineMode: isOfflineMode)
  }

  // MARK: - Selection Handling

  override func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    guard let playableContainer = dataSource.itemIdentifier(for: indexPath)?.playableContainable
    else { return }

    if let album = playableContainer as? Album {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToAlbumDetail(album: album),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let artist = playableContainer as? Artist {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToArtistDetail(artist: artist),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let playlist = playableContainer as? Playlist {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToPlaylistDetail(playlist: playlist),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let podcastEpisode = playableContainer as? PodcastEpisode,
              let podcast = podcastEpisode.podcast {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToPodcastDetail(
          podcast: podcast,
          episodeToScrollTo: podcastEpisode
        ),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let podcast = playableContainer as? Podcast {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToPodcastDetail(podcast: podcast),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let _ = playableContainer as? Radio {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToRadios(),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    } else if let genre = playableContainer as? Genre {
      navigationController?.pushViewController(
        AppStoryboard.Main.segueToGenreDetail(genre: genre),
        animated: true
      )
      navigationController?.navigationBar.prefersLargeTitles = false
    }
  }

  func updateAlbumsRecent() {
    if let albums = albumsRecentFetchController?.fetchedObjects as? [AlbumMO] {
      data[.recentAlbums] = albums.prefix(Self.sectionMaxItemCount)
        .compactMap { Album(managedObject: $0) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }

  func updateAlbumsLatest() {
    if let albums = albumsLatestFetchController?.fetchedObjects as? [AlbumMO] {
      data[.latestAlbums] = albums.prefix(Self.sectionMaxItemCount)
        .compactMap { Album(managedObject: $0) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }

  func updateRandomAlbums(isOfflineMode: Bool) {
    Task { @MainActor in
      let randomAlbums = appDelegate.storage.main.library.getRandomAlbums(
        for: self.appDelegate.account,
        count: Self.sectionMaxItemCount,
        onlyCached: isOfflineMode
      )
      data[.randomAlbums] = randomAlbums.compactMap {
        Item(playableContainable: $0)
      }
      applySnapshot(animated: true)
    }
  }

  func updateRandomArtists(isOfflineMode: Bool) {
    Task { @MainActor in
      let randomArtists = appDelegate.storage.main.library.getRandomArtists(
        for: self.appDelegate.account,
        count: Self.sectionMaxItemCount,
        onlyCached: isOfflineMode
      )
      data[.randomArtists] = randomArtists.compactMap {
        Item(playableContainable: $0)
      }
      applySnapshot(animated: true)
    }
  }

  func updateRandomGenres() {
    Task { @MainActor in
      let randomGenres = appDelegate.storage.main.library.getRandomGenres(
        for: appDelegate.account,
        count: Self.sectionMaxItemCount
      )
      data[.randomGenres] = randomGenres.compactMap {
        Item(playableContainable: $0)
      }
      applySnapshot(animated: true)
    }
  }

  func updateRandomSongs(isOfflineMode: Bool) {
    Task { @MainActor in
      let randomSongs = appDelegate.storage.main.library.getRandomSongs(
        for: appDelegate.account,
        count: Self.sectionMaxItemCount,
        onlyCached: isOfflineMode
      )
      data[.randomSongs] = randomSongs.compactMap {
        Item(playableContainable: $0)
      }
      applySnapshot(animated: true)
    }
  }

  func updatePlaylistsLastTimePlayed() {
    if let playlists = playlistsLastTimePlayedFetchController?.fetchedObjects as? [PlaylistMO] {
      data[.lastTimePlayedPlaylists] = playlists.prefix(Self.sectionMaxItemCount)
        .compactMap { Playlist(
          library: appDelegate.storage.main.library,
          managedObject: $0
        ) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }

  func updatePodcastEpisodesLatest() {
    if let podcastEpisodes = podcastEpisodesFetchedController?
      .fetchedObjects as? [PodcastEpisodeMO] {
      data[.latestPodcastEpisodes] = podcastEpisodes.prefix(Self.sectionMaxItemCount)
        .compactMap { PodcastEpisode(managedObject: $0) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }

  func updatePodcasts() {
    if let podcasts = podcastsFetchedController?.fetchedObjects as? [PodcastMO] {
      data[.podcasts] = podcasts.prefix(Self.sectionMaxItemCount)
        .compactMap { Podcast(managedObject: $0) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }

  func updateRadios() {
    if let radios = radiosFetchedController?.fetchedObjects as? [RadioMO] {
      data[.radios] = radios.prefix(Self.sectionMaxItemCount)
        .compactMap { Radio(managedObject: $0) }.compactMap {
          Item(playableContainable: $0)
        }
      applySnapshot(animated: true)
    }
  }
}

extension HomeVC: @preconcurrency NSFetchedResultsControllerDelegate {
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    // fetch controller is created on Main thread -> Runtime Error if this function call is not on Main thread
    MainActor.assumeIsolated {
      if controller == albumsRecentFetchController?.fetchResultsController {
        updateAlbumsRecent()
      } else if controller == albumsLatestFetchController?.fetchResultsController {
        updateAlbumsLatest()
      } else if controller == playlistsLastTimePlayedFetchController?.fetchResultsController {
        updatePlaylistsLastTimePlayed()
      } else if controller == podcastEpisodesFetchedController?.fetchResultsController {
        updatePodcastEpisodesLatest()
      } else if controller == podcastsFetchedController?.fetchResultsController {
        updatePodcasts()
      } else if controller == radiosFetchedController?.fetchResultsController {
        updateRadios()
      }
    }
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  )
    -> UIContextMenuConfiguration? {
    guard let containable = dataSource.itemIdentifier(for: indexPath)?.playableContainable
    else { return nil }

    let identifier = NSString(string: TableViewPreviewInfo(
      playableContainerIdentifier: containable.containerIdentifier,
      indexPath: indexPath
    ).asJSONString())
    return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
      let vc = EntityPreviewVC()
      vc.display(container: containable, on: self)
      Task { @MainActor in
        do {
          try await containable.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Preview Sync", error: error)
        }
        vc.refresh()
      }
      return vc
    }) { suggestedActions in
      var playIndexCB: (() -> PlayContext?)?
      playIndexCB = { PlayContext(containable: containable) }
      return EntityPreviewActionBuilder(
        container: containable,
        on: self,
        playContextCb: playIndexCB
      ).createMenu()
    }
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionCommitAnimating
  ) {
    animator.addCompletion {
      if let identifier = configuration.identifier as? String,
         let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
         let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
         let container = self.appDelegate.storage.main.library
         .getContainer(identifier: containerIdentifier) {
        EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
      }
    }
  }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UICollectionReusableView {
  static let reuseID = "SectionHeaderView"

  private let refreshButton: UIButton = {
    let btn = UIButton(type: .system)
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.setImage(UIImage.refresh, for: .normal)
    btn.isHidden = true
    btn.accessibilityLabel = "Refresh Randoms"
    return btn
  }()

  private let titleLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.font = UIFont.preferredFont(forTextStyle: .title3).withWeight(.semibold)
    lbl.textColor = .label
    return lbl
  }()

  var showsRefreshButton: Bool {
    get { !refreshButton.isHidden }
    set { refreshButton.isHidden = !newValue }
  }

  func setRefreshHandler(_ handler: (() -> ())?) {
    refreshButton.removeTarget(nil, action: nil, for: .allEvents)
    guard let handler else { return }
    refreshButton.addAction(UIAction { _ in handler() }, for: .touchUpInside)
  }

  var title: String? {
    didSet { titleLabel.text = title }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(titleLabel)
    addSubview(refreshButton)
    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: refreshButton.leadingAnchor,
        constant: -8
      ),
      titleLabel.topAnchor.constraint(equalTo: topAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    addSubview(titleLabel)
    addSubview(refreshButton)
    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: refreshButton.leadingAnchor,
        constant: -8
      ),
      titleLabel.topAnchor.constraint(equalTo: topAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}

extension UIFont {
  fileprivate func withWeight(_ weight: UIFont.Weight) -> UIFont {
    let descriptor = fontDescriptor.addingAttributes([
      UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight],
    ])
    return UIFont(descriptor: descriptor, size: pointSize)
  }
}
