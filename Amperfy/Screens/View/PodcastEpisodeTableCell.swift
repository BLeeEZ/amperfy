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
        appDelegate.player.play(context: PlayContext(name: episode.title, playables: [episode]))
    }
    
    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let episode = self.episode, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(
            playable: episode,
            playContextCb: {() in PlayContext(name: episode.title, playables: [episode])},
            on: rootView)
        rootView.present(detailVC, animated: true)
    }

}
