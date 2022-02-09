import Foundation
import UIKit

typealias GetPlayContextCallback = () -> PlayContext?
typealias GetPlayerIndexCallback = () -> PlayerIndex?

class LibraryEntityDetailVC: UIViewController {
    
    @IBOutlet weak var mainStackView: UIStackView!
    
    @IBOutlet weak var elementInfoStackView: UIStackView!
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var showArtistButton: UIButton!
    @IBOutlet weak var albumLabel: MarqueeLabel!
    @IBOutlet weak var showAlbumButton: UIButton!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    
    @IBOutlet weak var queueContainerView: UIView!
    @IBOutlet weak var userQueueInsertButton: BasicButton!
    @IBOutlet weak var userQueueAppendButton: BasicButton!
    @IBOutlet weak var contextQueueInsertButton: BasicButton!
    @IBOutlet weak var contextQueueAppendButton: BasicButton!
    
    @IBOutlet weak var ratingPlaceholderView: UIView!
    @IBOutlet weak var ratingView: RatingView?

    @IBOutlet weak var mainClusterStackView: UIStackView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var playShuffledButton: BasicButton!
    @IBOutlet weak var addToPlaylistButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var deleteCacheButton: UIButton!
    @IBOutlet weak var deleteOnServerButton: UIButton!
    private var buttonsOfMainCluster: [UIButton] {
        return [
            playButton,
            playShuffledButton,
            addToPlaylistButton,
            downloadButton,
            deleteCacheButton,
            deleteOnServerButton,
        ]
    }

    @IBOutlet weak var playerStackView: UIStackView!
    @IBOutlet weak var clearPlayerButton: UIButton!
    @IBOutlet weak var clearUserQueueButton: UIButton!
    @IBOutlet weak var addContextQueueToPlaylistButton: UIButton!

    private var playerControlButtons: [UIButton] {
        return [
            clearPlayerButton,
            clearUserQueueButton,
            addContextQueueToPlaylistButton
        ]
    }

    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var detailLabelsClusterHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var ratingHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var queueStackHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mainStackClusterHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playerStackClusterHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonHeightConstraint: NSLayoutConstraint!
    
    private var rootView: UIViewController?
    private var playContextCb: GetPlayContextCallback?
    private var playerIndexCb: GetPlayerIndexCallback?
    private var appDelegate: AppDelegate!
    private var playable: AbstractPlayable?
    private var album: Album?
    private var artist: Artist?
    private var genre: Genre?
    private var playlist: Playlist?
    private var podcast: Podcast?
    
    private var entityContainer: PlayableContainable! {
        if let playable = playable {
            return playable
        } else if let album = album {
            return album
        } else if let artist = artist {
            return artist
        } else if let genre = genre {
            return genre
        } else if let playlist = playlist {
            return playlist
        } else if let podcast = podcast {
            return podcast
        }
        return nil
    }

    private var entityPlayables: [AbstractPlayable] {
        return entityContainer?.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode) ?? [AbstractPlayable]()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        titleLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        albumLabel.applyAmperfyStyle()
        infoLabel.applyAmperfyStyle()
        if let ratingView = ViewBuilder<RatingView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: ratingPlaceholderView.bounds.size.width, height: RatingView.frameHeight+10)) {
            self.ratingView = ratingView
            ratingPlaceholderView.addSubview(ratingView)
        }
        ratingPlaceholderView.layer.cornerRadius = BasicButton.cornerRadius
        playerStackView.isHidden = true
        refresh()

        Self.configureRoundQueueButton(button: userQueueInsertButton, corner: .layerMinXMinYCorner)
        Self.configureRoundQueueButton(button: userQueueAppendButton, corner: .layerMaxXMinYCorner)
        Self.configureRoundQueueButton(button: contextQueueInsertButton, corner: .layerMinXMaxYCorner)
        Self.configureRoundQueueButton(button: contextQueueAppendButton, corner: .layerMaxXMaxYCorner)

        if !playButton.isHidden {
            playButton.imageView?.contentMode = .scaleAspectFit
        }
        if !playShuffledButton.isHidden {
            playShuffledButton.imageView?.contentMode = .scaleAspectFit
        }
    }
    
    override func viewWillLayoutSubviews() {
        var remainingSpace = mainStackView.frame.size.height
        remainingSpace -= detailLabelsClusterHeightConstraint.constant
        if !ratingPlaceholderView.isHidden {
            remainingSpace -= ratingHeightConstraint.constant
        }
        if !queueContainerView.isHidden {
            remainingSpace -= queueStackHeightConstraint.constant
        }
        remainingSpace -= mainStackClusterHeightConstraint.constant
        if !playerStackView.isHidden {
            remainingSpace -= playerStackClusterHeightConstraint.constant
        }
        remainingSpace -= cancelButtonHeightConstraint.constant
        // Big Artwork
        if remainingSpace > detailLabelsClusterHeightConstraint.constant {
            elementInfoStackView.alignment = .fill
            elementInfoStackView.axis = .vertical
            titleLabel.textAlignment = .center
            artistLabel.textAlignment = .center
            albumLabel.textAlignment = .center
            infoLabel.textAlignment = .center
        } else {
            elementInfoStackView.alignment = .fill
            elementInfoStackView.axis = .horizontal
            titleLabel.textAlignment = .left
            artistLabel.textAlignment = .left
            albumLabel.textAlignment = .left
            infoLabel.textAlignment = .left
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        guard self.appDelegate.persistentStorage.settings.isOnlineMode else { return }
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendProxy.createLibrarySyncer()
            if let song = self.playable?.asSong {
                let songAsync = Song(managedObject: context.object(with: song.managedObject.objectID) as! SongMO)
                syncer.sync(song: songAsync, library: syncLibrary)
            } else if let album = self.album {
                let albumAsync = Album(managedObject: context.object(with: album.managedObject.objectID) as! AlbumMO)
                syncer.sync(album: albumAsync, library: syncLibrary)
            } else if let artist = self.artist {
                let artistAsync = Artist(managedObject: context.object(with: artist.managedObject.objectID) as! ArtistMO)
                syncer.sync(artist: artistAsync, library: syncLibrary)
            } else if let genre = self.genre {
                let genreAsync = Genre(managedObject: context.object(with: genre.managedObject.objectID) as! GenreMO)
                syncer.sync(genre: genreAsync, library: syncLibrary)
            } else if let playlist = self.playlist {
                let playlistAsync = Playlist(library: syncLibrary, managedObject: context.object(with: playlist.managedObject.objectID) as! PlaylistMO)
                syncer.syncDown(playlist: playlistAsync, library: syncLibrary)
            } else if let podcast = self.podcast {
                let podcastAsync = Podcast(managedObject: context.object(with: podcast.managedObject.objectID) as! PodcastMO)
                syncer.sync(podcast: podcastAsync, library: syncLibrary)
            }
            syncLibrary.saveContext()
            DispatchQueue.main.async {
                self.refresh()
            }
        }
    }
    
    static func configureRoundQueueButton(button: UIButton, corner: CACornerMask) {
        button.contentMode = .center
        button.imageView?.contentMode = .scaleAspectFill
        button.titleLabel!.lineBreakMode = .byWordWrapping
        button.layer.maskedCorners = [corner]
    }
    
    static func configureRoundButtonCluster(buttons: [UIButton], containerView: UIView, hightConstraint: NSLayoutConstraint, buttonHeight: CGFloat) {
        guard !containerView.isHidden else { return }
        let visibleButtons = buttons.filter{!$0.isHidden}
        var height = 0.0
        if visibleButtons.count == 1 {
            height = buttonHeight
        } else if visibleButtons.count > 1 {
            height = ((buttonHeight + 1.0) * CGFloat(visibleButtons.count)) - 1
        }
        hightConstraint.constant = height
        containerView.isHidden = visibleButtons.isEmpty
        
        if visibleButtons.count == 1 {
            visibleButtons[0].layer.cornerRadius = BasicButton.cornerRadius
            visibleButtons[0].layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            visibleButtons.forEach{ $0.layer.maskedCorners = [] }
            let firstButton = visibleButtons.first
            firstButton?.layer.cornerRadius = BasicButton.cornerRadius
            firstButton?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            let lastButton = visibleButtons.last
            lastButton?.layer.cornerRadius = BasicButton.cornerRadius
            lastButton?.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
    }
    
    func display(podcast: Podcast, on rootView: UIViewController) {
        self.podcast = podcast
        self.rootView = rootView
    }
    
    func display(playlist: Playlist, on rootView: UIViewController) {
        self.playlist = playlist
        self.rootView = rootView
    }
    
    func display(genre: Genre, on rootView: UIViewController) {
        self.genre = genre
        self.rootView = rootView
    }

    func display(artist: Artist, on rootView: UIViewController) {
        self.artist = artist
        self.rootView = rootView
    }

    func display(album: Album, on rootView: UIViewController) {
        self.album = album
        self.rootView = rootView
    }
    
    func display(playable: AbstractPlayable, playContextCb: GetPlayContextCallback?, on rootView: UIViewController, playerIndexCb: GetPlayerIndexCallback? = nil) {
        self.playable = playable
        self.playContextCb = playContextCb
        self.playerIndexCb = playerIndexCb
        self.rootView = rootView
    }

    func refresh() {
        if let song = playable?.asSong {
            configureFor(song: song)
        } else if let podcastEpisode = playable?.asPodcastEpisode {
            configureFor(podcastEpisode: podcastEpisode)
        } else if let album = album {
            configureFor(album: album)
        } else if let artist = artist {
            configureFor(artist: artist)
        } else if let genre = genre {
            configureFor(genre: genre)
        } else if let playlist = playlist {
            configureFor(playlist: playlist)
        } else if let podcast = podcast {
            configureFor(podcast: podcast)
        }
        Self.configureRoundButtonCluster(buttons: buttonsOfMainCluster, containerView: mainClusterStackView, hightConstraint: mainStackClusterHeightConstraint, buttonHeight: playButtonHeightConstraint.constant)
    }

    private func configureFor(playlist: Playlist) {
        titleLabel.text = playlist.name
        artistLabel.isHidden = true
        showArtistButton.isHidden = true
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.refresh()
        infoLabel.text = playlist.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if !playlist.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            queueContainerView.isHidden = true
        }
        addToPlaylistButton.isHidden = true
        if playlist.hasCachedPlayables {
            downloadButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingPlaceholderView.isHidden = true
    }
    
    private func configureFor(genre: Genre) {
        titleLabel.text = genre.name
        artistLabel.isHidden = true
        showArtistButton.isHidden = true
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.displayAndUpdate(entity: genre, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = genre.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if !genre.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            queueContainerView.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if genre.hasCachedPlayables {
            downloadButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingPlaceholderView.isHidden = true
    }
    
    private func configureFor(podcast: Podcast) {
        titleLabel.text = podcast.title
        artistLabel.isHidden = true
        showArtistButton.isHidden = true
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.displayAndUpdate(entity: podcast, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = podcast.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if !podcast.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            queueContainerView.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if podcast.hasCachedPlayables {
            downloadButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingPlaceholderView.isHidden = true
    }
    
    private func configureFor(artist: Artist) {
        titleLabel.text = artist.name
        artistLabel.isHidden = true
        showArtistButton.isHidden = true
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.displayAndUpdate(entity: artist, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = artist.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if !artist.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            queueContainerView.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if artist.hasCachedPlayables {
            downloadButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingView?.display(entity: artist)
    }
    
    private func configureFor(album: Album) {
        titleLabel.text = album.name
        artistLabel.text = album.artist?.name ?? ""
        if album.artist == nil {
            showArtistButton.isHidden = true
        }
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.displayAndUpdate(entity: album, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = album.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if !album.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            queueContainerView.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if album.hasCachedPlayables {
            downloadButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingView?.display(entity: album)
    }
    
    private func configureFor(song: Song) {
        titleLabel.text = song.title
        artistLabel.text = song.creatorName
        if song.asSong?.artist == nil {
            showArtistButton.isHidden = true
        }
        albumLabel.text = song.asSong?.album?.name
        if song.asSong?.album == nil {
            showAlbumButton.isHidden = true
        }
        artworkImage.displayAndUpdate(entity: song, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = song.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if (playContextCb == nil) || (!song.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            playButton.isHidden = true
        }
        playShuffledButton.isHidden = true
        if (playContextCb == nil) || playerIndexCb != nil || (!song.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            queueContainerView.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if song.isCached {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = true
        ratingView?.display(entity: playable)
        configurePlayerStack()
    }
    
    private func configureFor(podcastEpisode: PodcastEpisode) {
        titleLabel.text = podcastEpisode.title
        artistLabel.text = podcastEpisode.creatorName
        if podcastEpisode.asPodcastEpisode?.podcast == nil {
            showArtistButton.isHidden = true
        }
        albumLabel.text = ""
        showAlbumButton.isHidden = true
        artworkImage.displayAndUpdate(entity: podcastEpisode, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        infoLabel.text = podcastEpisode.info(for: appDelegate.backendProxy.selectedApi, type: .long)

        if (playContextCb == nil) ||
           (!podcastEpisode.isAvailableToUser && appDelegate.persistentStorage.settings.isOnlineMode) ||
           (!podcastEpisode.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            playButton.isHidden = true
        }
        playShuffledButton.isHidden = true
        if (playContextCb == nil) ||
           (playerIndexCb != nil) ||
           (!podcastEpisode.isAvailableToUser && appDelegate.persistentStorage.settings.isOnlineMode) ||
           (!podcastEpisode.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            queueContainerView.isHidden = true
        }
        addToPlaylistButton.isHidden = true
        if podcastEpisode.isCached {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = false
        } else if podcastEpisode.isAvailableToUser && appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        deleteOnServerButton.isHidden = podcastEpisode.remoteStatus == .deleted || appDelegate.persistentStorage.settings.isOfflineMode
        ratingPlaceholderView.isHidden = true
        configurePlayerStack()
    }
    
    func configurePlayerStack() {
        guard playContextCb == nil else {
            playerStackView.isHidden = true
            return
        }
        
        playerStackView.isHidden = false
        clearPlayerButton.isHidden = false
        clearUserQueueButton.isHidden = appDelegate.player.userQueue.isEmpty
        addContextQueueToPlaylistButton.isHidden = appDelegate.persistentStorage.settings.isOfflineMode
        
        Self.configureRoundButtonCluster(buttons: playerControlButtons, containerView: playerStackView, hightConstraint: playerStackClusterHeightConstraint, buttonHeight: playButtonHeightConstraint.constant)
    }
    
    @IBAction func pressedPlay(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        if let playerIndex = playerIndexCb?() {
            self.appDelegate.player.play(playerIndex: playerIndex)
        } else if let context = playContextCb?() {
            self.appDelegate.player.play(context: context)
        } else {
            self.appDelegate.player.play(context: PlayContext(name: entityContainer.name, playables: entityPlayables))
        }
    }
    
    @IBAction func pressPlayShuffled(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        if let context = playContextCb?() {
            self.appDelegate.player.playShuffled(context: context)
        } else {
            self.appDelegate.player.playShuffled(context: PlayContext(name: entityContainer.name, playables: entityPlayables))
        }
    }
    
    @IBAction func pressedAddToPlaylist(_ sender: Any) {
        dismiss(animated: true) {
            guard !self.entityPlayables.isEmpty else { return }
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.itemsToAdd = self.entityPlayables
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.rootView?.present(selectPlaylistNav, animated: true)
        }
    }

    @IBAction func pressedDownload(_ sender: Any) {
        dismiss(animated: true)
        if !entityPlayables.isEmpty {
            appDelegate.playableDownloadManager.download(objects: entityPlayables)
        }
    }
    
    @IBAction func pressedDeleteCache(_ sender: Any) {
        dismiss(animated: true)
        guard entityPlayables.hasCachedItems else { return }
        appDelegate.playableDownloadManager.removeFinishedDownload(for: entityPlayables)
        appDelegate.library.deleteCache(of: entityPlayables)
        appDelegate.library.saveContext()
        if let rootTableView = self.rootView as? UITableViewController{
            rootTableView.tableView.reloadData()
        }
        refresh()
    }
    
    @IBAction func pressedDeleteOnServer(_ sender: Any) {
        dismiss(animated: true)
        guard let podcastEpisode = playable?.asPodcastEpisode else { return }
        self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let episodeAsync = PodcastEpisode(managedObject: context.object(with: podcastEpisode.managedObject.objectID) as! PodcastEpisodeMO)
            syncer.requestPodcastEpisodeDelete(podcastEpisode: episodeAsync)
            if let podcastAsync = episodeAsync.podcast {
                syncer.sync(podcast: podcastAsync, library: library)
            }
        }
    }
    
    @IBAction func pressedShowArtist(_ sender: Any) {
        dismiss(animated: true) {
            if let artist = self.playable?.asSong?.artist ?? self.album?.artist {
                self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
                let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
                artistDetailVC.artist = artist
                if let popupPlayer = self.rootView as? PopupPlayerVC {
                    popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
                } else if let navController = self.rootView?.navigationController {
                    navController.pushViewController(artistDetailVC, animated: true)
                }
            } else if let podcast = self.playable?.asPodcastEpisode?.podcast {
                self.appDelegate.userStatistics.usedAction(.alertGoToPodcast)
                let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
                podcastDetailVC.podcast = podcast
                if let popupPlayer = self.rootView as? PopupPlayerVC {
                    popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
                } else if let navController = self.rootView?.navigationController {
                    navController.pushViewController(podcastDetailVC, animated: true)
                }
            }
        }
    }
    
    @IBAction func pressedShowAlbum(_ sender: Any) {
        let album = playable?.asSong?.album
        dismiss(animated: true) {
            guard let album = album  else { return }
            self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            if let popupPlayer = self.rootView as? PopupPlayerVC {
                popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
            } else if let navController = self.rootView?.navigationController {
                navController.pushViewController(albumDetailVC, animated: true)
            }
        }
    }
    
    @IBAction func pressedInsertUserQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertUserQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedAppendUserQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendUserQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedInsertContextQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertContextQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedAppendContextQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendContextQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedClearPlayer(_ sender: Any) {
        dismiss(animated: true)
        self.appDelegate.player.clearQueues()
        if let popupPlayer = self.rootView as? PopupPlayerVC {
            popupPlayer.reloadData()
            popupPlayer.playerView?.refreshPlayer()
        }
    }
    
    @IBAction func pressedClearUserQueue(_ sender: Any) {
        dismiss(animated: true)
        if let popupPlayer = self.rootView as? PopupPlayerVC {
            popupPlayer.clearUserQueue()
        }
    }
    
    @IBAction func pressedAddContextQueueToPlaylist(_ sender: Any) {
        dismiss(animated: true)
        let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
        var itemsToAdd = self.appDelegate.player.prevQueue.filterSongs()
        if let currentlyPlaying = self.appDelegate.player.currentlyPlaying, currentlyPlaying.isSong {
            itemsToAdd.append(currentlyPlaying)
        }
        itemsToAdd.append(contentsOf: self.appDelegate.player.nextQueue.filterSongs())
        selectPlaylistVC.itemsToAdd = itemsToAdd
        let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
        rootView?.present(selectPlaylistNav, animated: true, completion: nil)
    }
    
    @IBAction func pressedCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
