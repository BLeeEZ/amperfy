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
    @IBOutlet weak var handleCacheButton: UIButton!
    @IBOutlet weak var showArtistButton: UIButton!
    @IBOutlet weak var showAlbumButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private var rootView: UIViewController?
    private var appDelegate: AppDelegate!
    private var playable: AbstractPlayable?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        if let ratingView = ViewBuilder<RatingView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: ratingPlaceholderView.bounds.size.width, height: RatingView.frameHeight)) {
            self.ratingView = ratingView
            ratingPlaceholderView.addSubview(ratingView)
        }
        ratingPlaceholderView.backgroundColor = .clear
        if let playable = playable {
            configureForPlayable(playable: playable)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    private func configureForPlayable(playable: AbstractPlayable) {
        titleLabel.text = playable.title
        artistLabel.text = playable.creatorName
        albumLabel.text = playable.asSong?.album?.name
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
            handleCacheButton.setTitle("Remove from Cache", for: .normal)
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            handleCacheButton.setTitle("Download", for: .normal)
        } else {
            handleCacheButton.isHidden = true
        }
        if playable.asSong?.artist == nil {
            showArtistButton.isHidden = true
        }
        if playable.asSong?.album == nil {
            showAlbumButton.isHidden = true
        }
        ratingView?.prepare(entity: playable)
        
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
    
    func display(playable: AbstractPlayable, on rootView: UIViewController) {
        self.playable = playable
        self.rootView = rootView
    }

    @IBAction func pressedPlay(_ sender: Any) {
        dismiss(animated: true)
        if let playable = self.playable {
            self.appDelegate.player.play(playable: playable)
        }
    }
    
    @IBAction func pressedAddToPlaylist(_ sender: Any) {
        if let playable = playable {
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.itemsToAdd = [playable]
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            dismiss(animated: true) {
                self.rootView?.present(selectPlaylistNav, animated: true)
            }
        }
    }
    
    @IBAction func pressedHandleCache(_ sender: Any) {
        if let playable = playable {
            if playable.isCached {
                appDelegate.playableDownloadManager.removeFinishedDownload(for: playable)
                appDelegate.library.deleteCache(ofPlayable: playable)
                appDelegate.library.saveContext()
            } else if appDelegate.persistentStorage.settings.isOnlineMode {
                appDelegate.playableDownloadManager.download(object: playable)
            }
        }
    }
    
    @IBAction func pressedShowArtist(_ sender: Any) {
        if let song = playable?.asSong, let artist = song.artist {
            self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            if let navController = self.rootView?.navigationController {
                dismiss(animated: true) {
                    navController.pushViewController(artistDetailVC, animated: true)
                }
            }
        }
    }
    
    @IBAction func pressedShowAlbum(_ sender: Any) {
        if let song = playable?.asSong, let album = song.album {
            self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            if let navController = self.rootView?.navigationController {
                dismiss(animated: true) {
                    navController.pushViewController(albumDetailVC, animated: true)
                }
            }
        }
    }
    
    @IBAction func pressedInsertWaitingQueue(_ sender: Any) {
        dismiss(animated: true)
        guard let playable = self.playable else { return }
        self.appDelegate.player.insertFirstToWaitingQueue(playables: [playable])
    }
    
    @IBAction func pressedAppendWaitingQueue(_ sender: Any) {
        dismiss(animated: true)
        guard let playable = self.playable else { return }
        self.appDelegate.player.appendToWaitingQueue(playables: [playable])
    }
    
    @IBAction func pressedInsertNextInMainQueue(_ sender: Any) {
        dismiss(animated: true)
        guard let playable = self.playable else { return }
        self.appDelegate.player.insertFirstToNextInMainQueue(playables: [playable])
    }
    
    @IBAction func pressedAppendNextInMainQueue(_ sender: Any) {
        dismiss(animated: true)
        guard let playable = self.playable else { return }
        self.appDelegate.player.appendToNextInMainQueue(playables: [playable])
    }
    
    @IBAction func pressedCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
