//
//  EntityPreviewVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 12.02.24.
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

import Foundation
import UIKit
import AmperfyKit
import PromiseKit
import MarqueeLabel

typealias GetPlayContextCallback = () -> PlayContext?
typealias GetPlayerIndexCallback = () -> PlayerIndex?

class EntityPreviewActionBuilder {
    
    private var entityContainer: PlayableContainable
    private var rootView: UIViewController
    private var playContextCb: GetPlayContextCallback?
    private var playerIndexCb: GetPlayerIndexCallback?
    private var appDelegate: AppDelegate
    
    private var entityPlayables: [AbstractPlayable] {
        let playables = entityContainer.playables.filterCached(dependigOn: appDelegate.storage.settings.isOfflineMode)
        switch(entityContainer.playContextType) {
        case .music:
            return playables.compactMap{ $0.asSong }.filterServerDeleteUncachedSongs()
        case .podcast:
            return playables
        }
    }
    
    // configure states
    private var isPlay = false
    private var isShuffle = false
    private var isMusicQueue = false
    private var isPodcastQueue = false
    private var isShowAlbum = false
    private var isShowArtist = false
    private var isAddToPlaylist = false
    private var isDownloadPossible: Bool {
        return !(entityContainer.playables.isCachedCompletely ||
                 appDelegate.storage.settings.isOfflineMode ||
                 !entityContainer.isDownloadAvailable)
    }
    private var isDeleteOnServer = false
    private var isShowPodcastDetails = false
    
    init(container: PlayableContainable, on rootView: UIViewController, playContextCb: GetPlayContextCallback? = nil, playerIndexCb: GetPlayerIndexCallback? = nil) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.entityContainer = container
        self.rootView = rootView
        self.playContextCb = playContextCb
        self.playerIndexCb = playerIndexCb
    }

    public func createMenu() -> UIMenu {
        var menuActions = [UIMenuElement]()
        
        configureUI()
        
        var playActions = [UIMenuElement]()
        var gotoActions = [UIMenuElement]()
        var ratingFavActions = [UIMenuElement]()
        var elementHandlingActions = [UIMenuElement]()
        
        if isPlay {
            playActions.append(createPlayAction())
        }
        if isShuffle {
            playActions.append(createPlayShuffledAction())
        }
        if !playActions.isEmpty {
            menuActions.append(UIMenu(options: .displayInline, children: playActions))
        }
        if isMusicQueue {
            menuActions.append(createMusicQueueAction())
        }
        if isPodcastQueue {
            menuActions.append(createPodcastQueueAction())
        }
        if isShowAlbum {
            gotoActions.append(createShowAlbumAction())
        }
        if isShowArtist {
            gotoActions.append(createShowArtistAction())
        }
        if isShowPodcastDetails, let podcastEpisode = (entityContainer as? AbstractPlayable)?.asPodcastEpisode {
            gotoActions.append(createShowEpisodeDetailsAction(podcastEpisode: podcastEpisode))
        }
        if isShowPodcastDetails, let podcast = entityContainer as? Podcast {
            gotoActions.append(createShowPodcastDetailsAction(podcast: podcast))
        }
        if !gotoActions.isEmpty {
            menuActions.append(UIMenu(options: .displayInline, children: gotoActions))
        }
        if let libraryEntity = entityContainer as? AbstractLibraryEntity, entityContainer.isFavoritable {
            ratingFavActions.append(createFavoriteMenu(libraryEntity: libraryEntity))
        }
        if let libraryEntity = entityContainer as? AbstractLibraryEntity, entityContainer.isRateable {
            ratingFavActions.append(createRatingMenu(libraryEntity: libraryEntity))
        }
        if !ratingFavActions.isEmpty {
            menuActions.append(UIMenu(options: .displayInline, children: ratingFavActions))
        }
        if isAddToPlaylist {
            elementHandlingActions.append(createAddToPlaylistAction())
        }
        if isDownloadPossible {
            elementHandlingActions.append(createDownloadAction())
        }
        if entityContainer.playables.hasCachedItems {
            elementHandlingActions.append(createDeleteCacheAction())
        }
        if isDeleteOnServer {
            elementHandlingActions.append(createDeleteOnServerAction())
        }
        if !elementHandlingActions.isEmpty {
            menuActions.append(UIMenu(options: .displayInline, children: elementHandlingActions))
        }
        if appDelegate.storage.settings.isShowDetailedInfo {
            menuActions.append(createCopyIdToClipboardAction())
        }

        return UIMenu(options: .displayInline, children: menuActions)
    }
    
    public func performPreviewTransition() {
        if let playable = entityContainer as? AbstractPlayable {
            if let _ = playable.asSong, !(rootView is AlbumDetailVC) {
                showAlbum()
            } else if let _ = playable.asPodcastEpisode, !(rootView is PodcastDetailVC) {
                showArtist()
            }
        } else if let album = entityContainer as? Album {
            let detailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            detailVC.album = album
            if let navController = self.rootView.navigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        } else if let artist = entityContainer as? Artist {
            let detailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            detailVC.artist = artist
            if let navController = self.rootView.navigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        } else if let genre = entityContainer as? Genre {
            let detailVC = GenreDetailVC.instantiateFromAppStoryboard()
            detailVC.genre = genre
            if let navController = self.rootView.navigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        } else if let playlist = entityContainer as? Playlist {
            let detailVC = PlaylistDetailVC.instantiateFromAppStoryboard()
            detailVC.playlist = playlist
            if let navController = self.rootView.navigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        } else if let podcast = entityContainer as? Podcast {
            let detailVC = PodcastDetailVC.instantiateFromAppStoryboard()
            detailVC.podcast = podcast
            if let navController = self.rootView.navigationController {
                navController.pushViewController(detailVC, animated: true)
            }
        }
    }
    
    private func configureUI() {
        if let playable = entityContainer as? AbstractPlayable {
            if let song = playable.asSong {
                configureFor(song: song)
            } else if let podcastEpisode = playable.asPodcastEpisode {
                configureFor(podcastEpisode: podcastEpisode)
            }
        } else if let album = entityContainer as? Album {
            configureFor(album: album)
        } else if let artist = entityContainer as? Artist {
            configureFor(artist: artist)
        } else if let genre = entityContainer as? Genre {
            configureFor(genre: genre)
        } else if let playlist = entityContainer as? Playlist {
            configureFor(playlist: playlist)
        } else if let podcast = entityContainer as? Podcast {
            configureFor(podcast: podcast)
        }
    }
    
    private func configureFor(song: Song) {
        isPlay = !((playContextCb == nil) ||
                   (!song.isCached && appDelegate.storage.settings.isOfflineMode))
        isShuffle = !((playContextCb == nil) ||
                      playerIndexCb != nil ||
                      (!song.isCached && appDelegate.storage.settings.isOfflineMode))
        isMusicQueue = !((playContextCb == nil) ||
                         playerIndexCb != nil ||
                         (!song.isCached && appDelegate.storage.settings.isOfflineMode))
        isPodcastQueue = false
        isShowAlbum = !(rootView is AlbumDetailVC)
        isShowArtist = !(rootView is ArtistDetailVC)
        isAddToPlaylist = appDelegate.storage.settings.isOnlineMode
        isDeleteOnServer = false
        isShowPodcastDetails = false
    }
    
    private func configureFor(podcastEpisode: PodcastEpisode) {
        isPlay = !((playContextCb == nil) ||
                   (!podcastEpisode.isAvailableToUser && appDelegate.storage.settings.isOnlineMode) ||
                   (!podcastEpisode.isCached && appDelegate.storage.settings.isOfflineMode))
        isShuffle = false
        isMusicQueue = false
        isPodcastQueue = !((playContextCb == nil) ||
                           (playerIndexCb != nil) ||
                           (!podcastEpisode.isAvailableToUser && appDelegate.storage.settings.isOnlineMode) ||
                           (!podcastEpisode.isCached && appDelegate.storage.settings.isOfflineMode))
        isShowAlbum = false
        isShowArtist = !(rootView is PodcastDetailVC)
        isAddToPlaylist = false
        isDeleteOnServer = podcastEpisode.podcastStatus != .deleted && appDelegate.storage.settings.isOnlineMode
        isShowPodcastDetails = true
    }
    
    private func configureFor(playlist: Playlist) {
        isPlay = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isShuffle = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isMusicQueue = true
        isPodcastQueue = false
        isShowAlbum = false
        isShowArtist = false
        isAddToPlaylist = appDelegate.storage.settings.isOnlineMode
        isDeleteOnServer = false
        isShowPodcastDetails = false
    }
    
    private func configureFor(genre: Genre) {
        isPlay = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isShuffle = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isMusicQueue = true
        isPodcastQueue = false
        isShowAlbum = false
        isShowArtist = false
        isAddToPlaylist = appDelegate.storage.settings.isOnlineMode
        isDeleteOnServer = false
        isShowPodcastDetails = false
    }
    
    private func configureFor(podcast: Podcast) {
        isPlay = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isShuffle = false
        isMusicQueue = false
        isShowAlbum = false
        isShowArtist = false
        isPodcastQueue = true
        isAddToPlaylist = false
        isDeleteOnServer = false
        isShowPodcastDetails = true
    }
    
    private func configureFor(artist: Artist) {
        isPlay = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isShuffle = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isMusicQueue = true
        isPodcastQueue = false
        isShowAlbum = false
        isShowArtist = false
        isAddToPlaylist = appDelegate.storage.settings.isOnlineMode
        isDeleteOnServer = false
        isShowPodcastDetails = false
    }
    
    private func configureFor(album: Album) {
        isPlay = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isShuffle = appDelegate.storage.settings.isOnlineMode || entityContainer.playables.hasCachedItems
        isMusicQueue = true
        isPodcastQueue = false
        isShowAlbum = false
        isShowArtist = !(rootView is ArtistDetailVC)
        isAddToPlaylist = appDelegate.storage.settings.isOnlineMode
        isDeleteOnServer = false
        isShowPodcastDetails = false
    }
    
    private func createPlayAction() -> UIAction {
        return UIAction(title: "Play", image: .play) { action in
            guard !self.entityPlayables.isEmpty else { return }
            if let playerIndex = self.playerIndexCb?() {
                self.appDelegate.player.play(playerIndex: playerIndex)
            } else if let context = self.playContextCb?() {
                self.appDelegate.player.play(context: context)
            } else {
                self.appDelegate.player.play(context: PlayContext(containable: self.entityContainer, playables: self.entityPlayables))
            }
        }
    }
    
    private func createPlayShuffledAction() -> UIAction {
        return UIAction(title: "Shuffle", image: .shuffle) { action in
            guard !self.entityPlayables.isEmpty else { return }
            if let context = self.playContextCb?() {
                self.appDelegate.player.playShuffled(context: context)
            } else {
                self.appDelegate.player.playShuffled(context: PlayContext(containable: self.entityContainer, playables: self.entityPlayables))
            }
        }
    }
    
    private func createMusicQueueAction() -> UIMenuElement {
        return UIMenu(title: "Music Queue", children: [
            UIAction(title: "Insert Context Queue", image: .contextQueueInsert) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.insertContextQueue(playables: self.entityPlayables)
            },
            UIAction(title: "Append Context Queue", image: .contextQueueAppend) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.appendContextQueue(playables: self.entityPlayables)
            },
            UIAction(title: "Insert User Queue", image: .userQueueInsert) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.insertUserQueue(playables: self.entityPlayables)
            },
            UIAction(title: "Append User Queue", image: .userQueueAppend) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.appendUserQueue(playables: self.entityPlayables)
            }
        ])
    }

    private func createPodcastQueueAction() -> UIMenuElement {
        return UIMenu(options: .displayInline, children: [
            UIAction(title: "Insert Podcast Queue", image: .podcastQueueInsert) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.insertPodcastQueue(playables: self.entityPlayables)
            },
            UIAction(title: "Append Podcast Queue", image: .podcastQueueAppend) { action in
                guard !self.entityPlayables.isEmpty else { return }
                self.appDelegate.player.appendPodcastQueue(playables: self.entityPlayables)
            }
        ])
    }
    
    private func createFavoriteMenu(libraryEntity: AbstractLibraryEntity) -> UIAction {
        return libraryEntity.isFavorite ?
        UIAction(title: "Unmark favorite", image: .heartSlash) { action in self.toggleFavorite() } :
        UIAction(title: "Favorite", image: .heartEmpty) { action in self.toggleFavorite() }
    }
    
    private func toggleFavorite() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        firstly {
            entityContainer.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
        }
    }
    
    private func createRatingMenu(libraryEntity: AbstractLibraryEntity) -> UIMenu {
        let rating = libraryEntity.rating == 0 ? "Not rated" : "\(libraryEntity.rating) Star\(libraryEntity.rating > 1 ? "s" : "")"
        let children = [
            UIAction(title: "No Rating", image: .ban) { action in self.setRating(rating: 0) },
            UIAction(title: "1 Star" , image: libraryEntity.rating >= 1 ? .starFill : .starEmpty) { action in self.setRating(rating: 1) },
            UIAction(title: "2 Stars", image: libraryEntity.rating >= 2 ? .starFill : .starEmpty) { action in self.setRating(rating: 2) },
            UIAction(title: "3 Stars", image: libraryEntity.rating >= 3 ? .starFill : .starEmpty) { action in self.setRating(rating: 3) },
            UIAction(title: "4 Stars", image: libraryEntity.rating >= 4 ? .starFill : .starEmpty) { action in self.setRating(rating: 4) },
            UIAction(title: "5 Stars", image: libraryEntity.rating >= 5 ? .starFill : .starEmpty) { action in self.setRating(rating: 5) }
        ]
        
        if  #available(iOS 17, *) {
            return UIMenu(title: "Rating: \(rating)", options: .displayAsPalette, children: children)
        } else {
            return UIMenu(title: "Rating: \(rating)", options: .singleSelection, children: children)
        }
    }
    
    private func setRating(rating: Int) {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        if let song = (entityContainer as? AbstractPlayable)?.asSong {
            song.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(song: song, rating: rating)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Song Rating Sync", error: error)
            }
        } else if let album = entityContainer as? Album  {
            album.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(album: album, rating: rating)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Rating Sync", error: error)
            }
        } else if let artist = entityContainer as? Artist {
            artist.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(artist: artist, rating: rating)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Rating Sync", error: error)
            }
        }
    }
    
    private func createAddToPlaylistAction() -> UIAction {
        return UIAction(title: "Add to Playlist", image: .playlistPlus) { action in
            guard !self.entityPlayables.isEmpty else { return }
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.itemsToAdd = self.entityPlayables
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.rootView.present(selectPlaylistNav, animated: true)
        }
    }
    
    private func createShowAlbumAction() -> UIAction {
        return UIAction(title: "Show Album", image: .album) { action in
            self.showAlbum()
        }
    }
    
    private func showAlbum() {
        let playable = self.entityContainer as? AbstractPlayable
        let album = playable?.asSong?.album
        guard let album = album else { return }
        self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
        let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
        albumDetailVC.album = album
        albumDetailVC.songToScrollTo = playable?.asSong
        if let popupPlayer = self.rootView as? PopupPlayerVC {
            popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
        } else if let navController = self.rootView.navigationController {
            navController.pushViewController(albumDetailVC, animated: true)
        }
    }
    
    private func createShowArtistAction() -> UIAction {
        let title = ((self.entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) ? "Show Podcast" : "Show Artist"
        let image = ((self.entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) ? UIImage.squareArrow : UIImage.artist
        return UIAction(title: title, image: image) { action in
            self.showArtist()
        }
    }
    
    private func showArtist() {
        let playable = self.entityContainer as? AbstractPlayable
        let album = self.entityContainer as? Album
        if let artist = playable?.asSong?.artist ?? album?.artist {
            self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            artistDetailVC.albumToScrollTo = album
            if let popupPlayer = self.rootView as? PopupPlayerVC {
                popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
            } else if let navController = self.rootView.navigationController {
                navController.pushViewController(artistDetailVC, animated: true)
            }
        } else if let podcast = playable?.asPodcastEpisode?.podcast {
            self.appDelegate.userStatistics.usedAction(.alertGoToPodcast)
            let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
            podcastDetailVC.podcast = podcast
            podcastDetailVC.episodeToScrollTo = playable?.asPodcastEpisode
            if let popupPlayer = self.rootView as? PopupPlayerVC {
                popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
            } else if let navController = self.rootView.navigationController {
                navController.pushViewController(podcastDetailVC, animated: true)
            }
        }
    }
    
    private func createDownloadAction() -> UIAction {
        return UIAction(title: "Download", image: .download) { action in
            if !self.entityPlayables.isEmpty {
                self.appDelegate.playableDownloadManager.download(objects: self.entityPlayables)
            }
        }
    }
    
    private func createDeleteCacheAction() -> UIAction {
        return UIAction(title: "Delete Cache", image: .trash) { action in
            guard self.entityPlayables.hasCachedItems else { return }
            self.appDelegate.playableDownloadManager.removeFinishedDownload(for: self.entityPlayables)
            self.appDelegate.storage.main.library.deleteCache(of: self.entityPlayables)
            self.appDelegate.storage.main.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
        }
    }
    
    private func createDeleteOnServerAction() -> UIAction {
        return UIAction(title: "Delete on Server", image: .cloudX) { action in
            guard let playable = self.entityContainer as? AbstractPlayable, let podcastEpisode = playable.asPodcastEpisode else { return }
            firstly {
                self.appDelegate.librarySyncer.requestPodcastEpisodeDelete(podcastEpisode: podcastEpisode)
            }.then { () -> Promise<Void> in
                guard let podcast = podcastEpisode.podcast else { return Promise.value }
                return self.appDelegate.librarySyncer.sync(podcast: podcast)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Podcast Episode Sync Delete", error: error)
            }
        }
    }
    
    private func createShowPodcastDetailsAction(podcast: Podcast) -> UIAction {
        return UIAction(title: "Show Podcast Description", image: .info) { action in
            self.showPodcastDetails()
        }
    }
    
    private func createShowEpisodeDetailsAction(podcastEpisode: PodcastEpisode) -> UIAction {
        return UIAction(title: "Show Episode Description", image: .info) { action in
            self.showPodcastDetails()
        }
    }
    
    private func showPodcastDetails() {
        var descriptionVC: PodcastDescriptionVC?
        if let playable = entityContainer as? AbstractPlayable, let podcastEpisode = playable.asPodcastEpisode {
            descriptionVC = PodcastDescriptionVC()
            descriptionVC?.display(podcastEpisode: podcastEpisode, on: rootView)
        } else if let podcast = entityContainer as? Podcast {
            descriptionVC = PodcastDescriptionVC()
            descriptionVC?.display(podcast: podcast, on: rootView)
        }
        
        if let descriptionVC = descriptionVC {
            rootView.present(descriptionVC, animated: true)
        }
    }
    
    private func createCopyIdToClipboardAction() -> UIMenu {
        return UIMenu(options: .displayInline, children: [UIAction(title: "Copy ID to Clipboard", image: .clipboard) { action in
            if !self.entityContainer.id.isEmpty {
                UIPasteboard.general.string = self.entityContainer.id
            }
        }])
    }

}

class EntityPreviewVC: UIViewController {
    
    static let margin = UIEdgeInsets(top: UIView.defaultMarginX, left: UIView.defaultMarginX, bottom: UIView.defaultMarginX, right: UIView.defaultMarginX)
    
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var entityImageView: EntityImageView!
    @IBOutlet weak var gotoDetailsSymbol: UIImageView!
    
    private var rootView: UIViewController?
    private var appDelegate: AppDelegate!
    private var entityContainer: PlayableContainable?
    
    var isNavigationDisallowed: Bool {
        return (
            ((entityContainer as? AbstractPlayable)?.isSong ?? false) && (rootView is AlbumDetailVC) ||
            ((entityContainer as? AbstractPlayable)?.isPodcastEpisode ?? false) && (rootView is PodcastDetailVC)
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.view.setBackgroundBlur(style: .prominent)
        self.view.backgroundColor = .clear
        titleLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        infoLabel.applyAmperfyStyle()
        gotoDetailsSymbol.isHidden = isNavigationDisallowed
        
        // The preview will size to the preferredContentSize, which can be useful
        // for displaying a preview with the dimension of an image, for example.
        // Unlike peek and pop, it doesn't seem to automatically scale down for you.

        let width = view.bounds.width
        let height = entityImageView.frame.height + Self.margin.top + Self.margin.bottom
        preferredContentSize = CGSize(width: width, height: height)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refresh()
    }

    func display(container: PlayableContainable, on rootView: UIViewController) {
        self.rootView = rootView
        self.entityContainer = container
    }

    func refresh() {
        guard let entityContainer = entityContainer else { return }
        entityImageView.display(container: entityContainer)
        titleLabel.text = entityContainer.name
        artistLabel.text = entityContainer.subtitle
        artistLabel.isHidden = entityContainer.subtitle == nil
        infoLabel.text = entityContainer.info(for: appDelegate.backendApi.selectedApi, details: DetailInfoType(type: .long, settings: appDelegate.storage.settings))
    }

}
