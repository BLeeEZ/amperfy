import UIKit

class PodcastEpisodeTableCell: BasicTableCell {
    
    @IBOutlet weak var podcastEpisodeLabel: UILabel!
    @IBOutlet weak var podcastEpisodeImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playEpisodeButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var playProgressBar: UIProgressView!
    @IBOutlet weak var playProgressLabel: UILabel!
    @IBOutlet weak var playProgressLabelPlayButtonDistance: NSLayoutConstraint!
    
    static let rowHeight: CGFloat = 143.0 + margin.bottom + margin.top
    
    private var episode: PodcastEpisode!
    private var rootView: UIViewController?
    
    func display(episode: PodcastEpisode, rootView: UIViewController) {
        self.episode = episode
        self.rootView = rootView
        refresh()
    }

    func refresh() {
        guard let episode = self.episode else { return }
        podcastEpisodeLabel.text = episode.title
        podcastEpisodeImage.displayAndUpdate(entity: episode, via: appDelegate.artworkDownloadManager)
        
        optionsButton.setTitle(CommonString.threeMiddleDots, for: .normal)
        if episode.isAvailableToUser {
            playEpisodeButton.setTitle(FontAwesomeIcon.Play.asString, for: .normal)
            playEpisodeButton.isEnabled = true
        } else {
            playEpisodeButton.setTitle(FontAwesomeIcon.Ban.asString, for: .normal)
            playEpisodeButton.isEnabled = false
        }
        infoLabel.text = "\(episode.publishDate.asShortDayMonthString)"
        descriptionLabel.text = episode.depiction ?? ""
        
        var progressText = ""
        if let remainingTime = episode.remainingTimeInSec, let playProgressPercent = episode.playProgressPercent {
            progressText = "\(remainingTime.asDurationString) left"
            playProgressBar.isHidden = false
            playProgressLabelPlayButtonDistance.constant = (2 * 8.0) + playProgressBar.frame.width
            playProgressBar.progress = playProgressPercent
        } else {
            progressText = "\(episode.duration.asDurationString)"
            playProgressBar.isHidden = true
            playProgressLabelPlayButtonDistance.constant = 8.0
        }
        if !episode.isAvailableToUser {
            progressText += " \(CommonString.oneMiddleDot) \(episode.userStatus.description)"
        }
        playProgressLabel.text = progressText
        if episode.isCached {
            playProgressLabel.textColor = .defaultBlue
        } else {
            playProgressLabel.textColor = .secondaryLabelColor
        }
    }

    @IBAction func playEpisodeButtonPressed(_ sender: Any) {
        guard let episode = self.episode else { return }
        appDelegate.player.appendContextQueueAndPlay(playable: episode)
    }
    
    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let episode = self.episode, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(
            playable: episode,
            playContextCb: {() in PlayContext(playables: [episode])},
            on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
    func createAlert(forEpisode episode: PodcastEpisode, rootView: UIViewController) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight))
        if let songActionSheetView = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight)) {
            songActionSheetView.display(playable: episode)
            headerView.addSubview(songActionSheetView)
            alert.view.addSubview(headerView)
        }
    
        if episode.isAvailableToUser {
            if episode.isCached || appDelegate.persistentStorage.settings.isOnlineMode {
                alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { _ in
                    self.appDelegate.player.play(context: PlayContext(playables: [episode]))
                }))
                alert.addAction(UIAlertAction(title: "Add to play next", style: .default, handler: { _ in
                    self.appDelegate.player.appendContextQueue(playables: [episode])
                }))
            }
            if episode.isCached {
                alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                    self.appDelegate.playableDownloadManager.removeFinishedDownload(for: episode)
                    self.appDelegate.library.deleteCache(ofPlayable: episode)
                    self.appDelegate.library.saveContext()
                    self.refresh()
                }))
            } else if appDelegate.persistentStorage.settings.isOnlineMode {
                alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                    self.appDelegate.playableDownloadManager.download(object: episode)
                    self.refresh()
                }))
            }
            if episode.remoteStatus != .deleted, appDelegate.persistentStorage.settings.isOnlineMode {
                alert.addAction(UIAlertAction(title: "Delete on server", style: .destructive, handler: { _ in
                    self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                        let library = LibraryStorage(context: context)
                        let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                        let episodeAsync = PodcastEpisode(managedObject: context.object(with: episode.managedObject.objectID) as! PodcastEpisodeMO)
                        syncer.requestPodcastEpisodeDelete(podcastEpisode: episodeAsync)
                        if let podcastAsync = episodeAsync.podcast {
                            syncer.sync(podcast: podcastAsync, library: library)
                        }
                    }
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        } else {
            alert.addAction(UIAlertAction(title: "Episode not available", style: .destructive))
        }
        
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }
    
}
