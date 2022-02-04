import Foundation
import UIKit

typealias GetPlayContextCallback = () -> PlayContext?
typealias GetPlayerIndexCallback = () -> PlayerIndex?

class LibraryEntityDetailVC: UIViewController {
    
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var showArtistButton: UIButton!
    @IBOutlet weak var albumLabel: MarqueeLabel!
    @IBOutlet weak var showAlbumButton: UIButton!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    
    @IBOutlet weak var userQueueInsertButton: BasicButton!
    @IBOutlet weak var userQueueAppendButton: BasicButton!
    @IBOutlet weak var contextQueueInsertButton: BasicButton!
    @IBOutlet weak var contextQueueAppendButton: BasicButton!
    
    @IBOutlet weak var ratingPlaceholderView: UIView!
    @IBOutlet weak var ratingView: RatingView?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var playShuffledButton: BasicButton!
    @IBOutlet weak var addToPlaylistButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var deleteCacheButton: UIButton!
    @IBOutlet weak var deleteOnServerButton: UIButton!
    
    @IBOutlet weak var playerStackView: UIStackView!
    @IBOutlet weak var clearPlayerButton: UIButton!
    @IBOutlet weak var clearUserQueueButton: UIButton!
    @IBOutlet weak var addContextQueueToPlaylistButton: UIButton!

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
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var mainStackClusterHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playerStackClusterHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playButtonHeightConstraint: NSLayoutConstraint!
    
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
    
    private var entityPlayables: [AbstractPlayable] {
        var playables = [AbstractPlayable]()
        if let playable = playable {
            playables = [playable]
        } else if let album = album {
            playables = album.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        } else if let artist = artist {
            playables = artist.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        } else if let genre = genre {
            playables = genre.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        } else if let playlist = playlist {
            playables = playlist.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        } else if let podcast = podcast {
            playables = podcast.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        }
        return playables
    }
    private var contextName: String {
        var name = ""
        if let playable = playable {
            name = playable.title
        } else if let album = album {
            name = album.name
        } else if let artist = artist {
            name = artist.name
        } else if let genre = genre {
            name = genre.name
        } else if let playlist = playlist {
            name = playlist.name
        } else if let podcast = podcast {
            name = podcast.title
        }
        return name
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

        userQueueInsertButton.contentMode = .center
        userQueueInsertButton.imageView?.contentMode = .scaleAspectFill
        userQueueInsertButton.titleLabel!.lineBreakMode = .byWordWrapping
        userQueueInsertButton.layer.maskedCorners = [.layerMinXMinYCorner]

        userQueueAppendButton.contentMode = .center
        userQueueAppendButton.imageView?.contentMode = .scaleAspectFill
        userQueueAppendButton.titleLabel!.lineBreakMode = .byWordWrapping;
        userQueueAppendButton.layer.maskedCorners = [.layerMaxXMinYCorner]

        contextQueueInsertButton.contentMode = .center
        contextQueueInsertButton.imageView?.contentMode = .scaleAspectFill
        contextQueueInsertButton.titleLabel!.lineBreakMode = .byWordWrapping
        contextQueueInsertButton.layer.maskedCorners = [.layerMinXMaxYCorner]

        contextQueueAppendButton.contentMode = .center
        contextQueueAppendButton.imageView?.contentMode = .scaleAspectFill
        contextQueueAppendButton.titleLabel!.lineBreakMode = .byWordWrapping
        contextQueueAppendButton.layer.maskedCorners = [.layerMaxXMaxYCorner]
        
        if !playButton.isHidden {
            playButton.imageView?.contentMode = .scaleAspectFit
        }
        if !playShuffledButton.isHidden {
            playShuffledButton.imageView?.contentMode = .scaleAspectFit
        }
        
        let visibleMainButtons = buttonsOfMainCluster.filter{!$0.isHidden}
        var mainStackHeight = 0.0
        if visibleMainButtons.count == 1 {
            mainStackHeight = playButtonHeightConstraint.constant
        } else if visibleMainButtons.count > 1 {
            mainStackHeight = ((playButtonHeightConstraint.constant + 1.0) * CGFloat(visibleMainButtons.count)) - 1
        }
        mainStackClusterHeightConstraint.constant = mainStackHeight
        
        let firstButtonCluster = visibleMainButtons.first
        firstButtonCluster?.layer.cornerRadius = BasicButton.cornerRadius
        firstButtonCluster?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let lastButtonCluster = visibleMainButtons.last
        if firstButtonCluster == lastButtonCluster {
            lastButtonCluster?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            lastButtonCluster?.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        lastButtonCluster?.layer.cornerRadius = BasicButton.cornerRadius
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
    }

    private func configureFor(playlist: Playlist) {
        titleLabel.text = playlist.name
        artistLabel.isHidden = true
        showArtistButton.isHidden = true
        albumLabel.isHidden =  true
        showAlbumButton.isHidden = true
        artworkImage.refresh()
        var infoContent = [String]()
        if playlist.songCount == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(playlist.songCount) Songs")
        }
        if playlist.isSmartPlaylist {
            infoContent.append("Smart Playlist")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !playlist.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        if genre.artists.count == 1 {
            infoContent.append("1 Artist")
        } else {
            infoContent.append("\(genre.artists.count) Artists")
        }
        if genre.albums.count == 1 {
            infoContent.append("1 Album")
        } else {
            infoContent.append("\(genre.albums.count) Albums")
        }
        if genre.songs.count == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(genre.songs.count) Songs")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !genre.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        if podcast.episodes.count == 1 {
            infoContent.append("1 Episode")
        } else {
            infoContent.append("\(podcast.episodes.count) Episodes")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !podcast.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        if artist.albumCount == 1 {
            infoContent.append("1 Album")
        } else {
            infoContent.append("\(artist.albumCount) Albums")
        }
        if artist.songCount == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(artist.songCount) Songs")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !artist.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        if album.songCount == 1 {
            infoContent.append("1 Song")
        } else {
            infoContent.append("\(album.songCount) Songs")
        }
        infoContent.append("\(album.duration.asDurationString)")
        if album.year > 0 {
            infoContent.append("Year \(album.year)")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !album.hasCachedPlayables && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            playShuffledButton.isHidden = true
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        if song.track > 0 {
            infoContent.append("Track \(song.track)")
        }
        if song.year > 0 {
            infoContent.append("Year \(song.year)")
        } else if let albumYear = song.album?.year, albumYear > 0 {
            infoContent.append("Year \(albumYear)")
        }
        infoContent.append("\(song.duration.asDurationString)")
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if (playContextCb == nil) || (!song.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            playButton.isHidden = true
        }
        playShuffledButton.isHidden = true
        if (playContextCb == nil) || playerIndexCb != nil || (!song.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        var infoContent = [String]()
        infoContent.append("\(podcastEpisode.publishDate.asShortDayMonthString)")
        if (!podcastEpisode.isAvailableToUser && appDelegate.persistentStorage.settings.isOnlineMode) ||
           (!podcastEpisode.isCached && appDelegate.persistentStorage.settings.isOfflineMode) {
            infoContent.append("Not Available")
        } else if let remainingTime = podcastEpisode.remainingTimeInSec {
            infoContent.append("\(remainingTime.asDurationString) left")
        } else {
            infoContent.append("\(podcastEpisode.duration.asDurationString)")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

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
            userQueueInsertButton.isHidden = true
            userQueueAppendButton.isHidden = true
            contextQueueInsertButton.isHidden = true
            contextQueueAppendButton.isHidden = true
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
        
        let playerButtons: [UIButton] = [
            clearPlayerButton,
            clearUserQueueButton,
            addContextQueueToPlaylistButton
        ]

        let visiblePlayerButtons = playerButtons.filter{!$0.isHidden}
        var stackHeight = 0.0
        if visiblePlayerButtons.count == 1 {
            stackHeight = playButtonHeightConstraint.constant
        } else if visiblePlayerButtons.count > 1 {
            stackHeight = ((playButtonHeightConstraint.constant + 1.0) * CGFloat(visiblePlayerButtons.count)) - 1
        }
        playerStackClusterHeightConstraint.constant = stackHeight
        
        let firstButton = visiblePlayerButtons.first
        firstButton?.layer.cornerRadius = BasicButton.cornerRadius
        firstButton?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let lastButton = visiblePlayerButtons.last
        lastButton?.layer.cornerRadius = BasicButton.cornerRadius
        if firstButton == lastButton {
            lastButton?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            lastButton?.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
    }
    
    @IBAction func pressedPlay(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        if let playerIndex = playerIndexCb?() {
            self.appDelegate.player.play(playerIndex: playerIndex)
        } else if let context = playContextCb?() {
            self.appDelegate.player.play(context: context)
        } else {
            self.appDelegate.player.play(context: PlayContext(name: contextName, playables: entityPlayables))
        }
    }
    
    @IBAction func pressPlayShuffled(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        if let context = playContextCb?() {
            self.appDelegate.player.playShuffled(context: context)
        } else {
            self.appDelegate.player.playShuffled(context: PlayContext(name: contextName, playables: entityPlayables))
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
        if let playable = playable, playable.isCached {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: playable)
            appDelegate.library.deleteCache(ofPlayable: playable)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        } else if let album = album, album.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: album.playables)
            appDelegate.library.deleteCache(of: album)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        } else if let artist = artist, artist.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: artist.playables)
            appDelegate.library.deleteCache(of: artist)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        } else if let genre = genre, genre.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: genre.playables)
            appDelegate.library.deleteCache(of: genre)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        } else if let podcast = podcast, podcast.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: podcast.playables)
            appDelegate.library.deleteCache(of: podcast)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        } else if let playlist = playlist, playlist.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: playlist.playables)
            appDelegate.library.deleteCache(of: playlist)
            appDelegate.library.saveContext()
            if let rootTableView = self.rootView as? UITableViewController{
                rootTableView.tableView.reloadData()
            }
            refresh()
        }
    }
    
    @IBAction func pressedDeleteOnServer(_ sender: Any) {
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
        dismiss(animated: true)
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
