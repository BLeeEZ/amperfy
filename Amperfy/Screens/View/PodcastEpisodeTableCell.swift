import UIKit

class PodcastEpisodeTableCell: BasicTableCell {
    
    @IBOutlet weak var podcastEpisodeLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playEpisodeButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var cacheIconImage: UIImageView!
    @IBOutlet weak var playProgressBar: UIProgressView!
    @IBOutlet weak var playProgressLabel: UILabel!
    @IBOutlet weak var playProgressLabelPlayButtonDistance: NSLayoutConstraint!
    
    static let rowHeight: CGFloat = 143.0 + margin.bottom + margin.top
    
    private var episode: PodcastEpisode!
    private var rootView: UIViewController?
    private var playIndicator: PlayIndicator!
    
    func display(episode: PodcastEpisode, rootView: UIViewController) {
        if playIndicator == nil {
            playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
        }
        self.episode = episode
        self.rootView = rootView
        refresh()
    }

    func refresh() {
        guard let episode = self.episode else { return }
        configurePlayEpisodeButton()
        playIndicator.display(playable: episode, rootView: playEpisodeButton)
        playIndicator.willDisplayIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.configurePlayEpisodeButton()
        }
        playIndicator.willHideIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.configurePlayEpisodeButton()
        }
        podcastEpisodeLabel.text = episode.title
        entityImage.display(container: episode)
        
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
            cacheIconImage.isHidden = false
            playProgressLabel.textColor = .secondaryLabelColor
        } else {
            cacheIconImage.isHidden = true
            playProgressLabel.textColor = .secondaryLabelColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        playIndicator.reset()
    }

    private func configurePlayEpisodeButton() {
        guard let episode = self.episode else { return }
        if episode == appDelegate.player.currentlyPlaying {
            playEpisodeButton.setTitle("", for: .normal)
            playEpisodeButton.isEnabled = false
        } else if episode.isAvailableToUser {
            playEpisodeButton.setTitle(FontAwesomeIcon.Play.asString, for: .normal)
            playEpisodeButton.isEnabled = true
        } else {
            playEpisodeButton.setTitle(FontAwesomeIcon.Ban.asString, for: .normal)
            playEpisodeButton.isEnabled = false
        }
        
    }
    
    @IBAction func playEpisodeButtonPressed(_ sender: Any) {
        guard let episode = self.episode else { return }
        appDelegate.player.play(context: PlayContext(containable: episode))
    }
    
    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let episode = self.episode, let rootView = rootView else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(
            container: episode,
            on: rootView,
            playContextCb: {() in PlayContext(containable: episode)})
        rootView.present(detailVC, animated: true)
    }

}
