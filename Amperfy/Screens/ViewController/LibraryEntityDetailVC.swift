import Foundation
import UIKit

class LibraryEntityDetailVC: UIViewController {
    
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var albumLabel: MarqueeLabel!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    
    @IBOutlet weak var waitingQueueInsertButton: BasicButton!
    @IBOutlet weak var waitingQueueAppendButton: BasicButton!
    @IBOutlet weak var mainNextInsertButton: BasicButton!
    @IBOutlet weak var mainNextAppendButton: BasicButton!
    
    @IBOutlet weak var ratingPlaceholderView: UIView!
    @IBOutlet weak var ratingView: RatingView?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var addToPlaylistButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var deleteCacheButton: UIButton!
    @IBOutlet weak var showArtistButton: UIButton!
    @IBOutlet weak var showAlbumButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private var rootView: UITableViewController?
    private var appDelegate: AppDelegate!
    private var playable: AbstractPlayable?
    private var album: Album?
    private var artist: Artist?
    
    private var entityPlayables: [AbstractPlayable] {
        var playables = [AbstractPlayable]()
        if let playable = playable {
            playables = [playable]
        } else if let album = album {
            playables = album.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        } else if let artist = artist {
            playables = artist.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode)
        }
        return playables
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        if let ratingView = ViewBuilder<RatingView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: ratingPlaceholderView.bounds.size.width, height: RatingView.frameHeight+10)) {
            self.ratingView = ratingView
            ratingPlaceholderView.addSubview(ratingView)
        }
        ratingPlaceholderView.layer.cornerRadius = 10
        if let playable = playable {
            configureFor(playable: playable)
        } else if let album = album {
            configureFor(album: album)
        } else if let artist = artist {
            configureFor(artist: artist)
        }
        
        waitingQueueInsertButton.contentMode = .center
        waitingQueueInsertButton.imageView?.contentMode = .scaleAspectFill
        waitingQueueInsertButton.titleLabel!.lineBreakMode = .byWordWrapping;
        
        waitingQueueAppendButton.contentMode = .center
        waitingQueueAppendButton.imageView?.contentMode = .scaleAspectFill
        waitingQueueAppendButton.titleLabel!.lineBreakMode = .byWordWrapping;

        mainNextInsertButton.contentMode = .center
        mainNextInsertButton.imageView?.contentMode = .scaleAspectFill
        mainNextInsertButton.titleLabel!.lineBreakMode = .byWordWrapping;

        mainNextAppendButton.contentMode = .center
        mainNextAppendButton.imageView?.contentMode = .scaleAspectFill
        mainNextAppendButton.titleLabel!.lineBreakMode = .byWordWrapping;
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
            }
            syncLibrary.saveContext()
            DispatchQueue.main.async {
                self.refresh()
            }
        }
    }
    
    func display(artist: Artist, on rootView: UITableViewController) {
        self.artist = artist
        self.rootView = rootView
    }

    func display(album: Album, on rootView: UITableViewController) {
        self.album = album
        self.rootView = rootView
    }
    
    func display(playable: AbstractPlayable, on rootView: UITableViewController) {
        self.playable = playable
        self.rootView = rootView
    }

    func refresh() {
        if let playable = playable {
            configureFor(playable: playable)
        } else if let album = album {
            configureFor(album: album)
        } else if let artist = artist {
            configureFor(artist: artist)
        }
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
            waitingQueueInsertButton.isHidden = true
            waitingQueueAppendButton.isHidden = true
            mainNextInsertButton.isHidden = true
            mainNextAppendButton.isHidden = true
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
            waitingQueueInsertButton.isHidden = true
            waitingQueueAppendButton.isHidden = true
            mainNextInsertButton.isHidden = true
            mainNextAppendButton.isHidden = true
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
        ratingView?.display(entity: album)
    }
    
    private func configureFor(playable: AbstractPlayable) {
        titleLabel.text = playable.title
        artistLabel.text = playable.creatorName
        if playable.asSong?.artist == nil {
            showArtistButton.isHidden = true
        }
        albumLabel.text = playable.asSong?.album?.name
        if playable.asSong?.album == nil {
            showAlbumButton.isHidden = true
        }
        artworkImage.displayAndUpdate(entity: playable, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
        var infoContent = [String]()
        if let song = playable.asSong {
            if song.track > 0 {
                infoContent.append("Track \(song.track)")
            }
            if song.year > 0 {
                infoContent.append("Year \(song.year)")
            } else if let albumYear = song.album?.year, albumYear > 0 {
                infoContent.append("Year \(albumYear)")
            }
            infoContent.append("\(song.duration.asDurationString)")
        }
        infoLabel.text = infoContent.joined(separator: " \(CommonString.oneMiddleDot) ")

        if !playable.isCached && appDelegate.persistentStorage.settings.isOfflineMode {
            playButton.isHidden = true
            waitingQueueInsertButton.isHidden = true
            waitingQueueAppendButton.isHidden = true
            mainNextInsertButton.isHidden = true
            mainNextAppendButton.isHidden = true
        }
        if appDelegate.persistentStorage.settings.isOfflineMode {
            addToPlaylistButton.isHidden = true
        }
        if playable.isCached {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = false
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            downloadButton.isHidden = false
            deleteCacheButton.isHidden = true
        } else {
            downloadButton.isHidden = true
            deleteCacheButton.isHidden = true
        }
        ratingView?.display(entity: playable)
    }
    
    @IBAction func pressedPlay(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.play(playables: entityPlayables)
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
        if !entityPlayables.isEmpty {
            appDelegate.playableDownloadManager.download(objects: entityPlayables)
        }
    }
    
    @IBAction func pressedDeleteCache(_ sender: Any) {
        if let playable = playable, playable.isCached {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: playable)
            appDelegate.library.deleteCache(ofPlayable: playable)
            appDelegate.library.saveContext()
            if let rootView = self.rootView {
                rootView.tableView.reloadData()
            }
            refresh()
        } else if let album = album, album.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: album.playables)
            appDelegate.library.deleteCache(of: album)
            appDelegate.library.saveContext()
            if let rootView = self.rootView {
                rootView.tableView.reloadData()
            }
            refresh()
        } else if let artist = artist, artist.hasCachedPlayables {
            appDelegate.playableDownloadManager.removeFinishedDownload(for: artist.playables)
            appDelegate.library.deleteCache(of: artist)
            appDelegate.library.saveContext()
            if let rootView = self.rootView {
                rootView.tableView.reloadData()
            }
            refresh()
        }
    }
    
    @IBAction func pressedShowArtist(_ sender: Any) {
        let artist = playable?.asSong?.artist ?? album?.artist
        dismiss(animated: true) {
            guard let artist = artist, let navController = self.rootView?.navigationController else { return }
            self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            navController.pushViewController(artistDetailVC, animated: true)
        }
    }
    
    @IBAction func pressedShowAlbum(_ sender: Any) {
        let album = playable?.asSong?.album
        dismiss(animated: true) {
            guard let album = album, let navController = self.rootView?.navigationController else { return }
            self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            navController.pushViewController(albumDetailVC, animated: true)
        }
    }
    
    @IBAction func pressedInsertWaitingQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertFirstToWaitingQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedAppendWaitingQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendToWaitingQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedInsertNextInMainQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.insertFirstToNextInMainQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedAppendNextInMainQueue(_ sender: Any) {
        dismiss(animated: true)
        guard !entityPlayables.isEmpty else { return }
        self.appDelegate.player.appendToNextInMainQueue(playables: entityPlayables)
    }
    
    @IBAction func pressedCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
