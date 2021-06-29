import UIKit
import MediaPlayer
import MarqueeLabel

enum PlayerDisplayStyle: Int {
    case compact = 0
    case large = 1
    
    static let defaultValue: PlayerDisplayStyle = .large
    
    mutating func switchToNextStyle() {
        switch self {
        case .compact:
            self = .large
        case .large:
            self = .compact
        }
    }
    
    var description : String {
        switch self {
        case .compact: return "Compact"
        case .large: return "Large"
        }
    }
}

class PlayerView: UIView {
  
    static private let frameHeightCompact: CGFloat = 285 + margin.top + margin.bottom
    static private let margin = UIEdgeInsets(top: 0, left: UIView.defaultMarginX, bottom: 20, right: UIView.defaultMarginX)
    static private let defaultAnimationDuration = TimeInterval(0.50)
    
    var lastDisplayedPlayable: AbstractPlayable?
    
    private var appDelegate: AppDelegate!
    private var player: MusicPlayer!
    private var rootView: PopupPlayerVC?
    private var displayStyle: PlayerDisplayStyle!
    
    @IBOutlet weak var titleCompactLabel: MarqueeLabel!
    @IBOutlet weak var titleCompactButton: UIButton!
    @IBOutlet weak var titleLargeLabel: MarqueeLabel!
    @IBOutlet weak var titleLargeButton: UIButton!
    
    @IBOutlet weak var artistNameCompactLabel: MarqueeLabel!
    @IBOutlet weak var artistNameCompactButton: UIButton!
    @IBOutlet weak var artistNameLargeLabel: MarqueeLabel!
    @IBOutlet weak var artistNameLargeButton: UIButton!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var displayPlaylistButton: UIButton!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    // Animation constraints
    @IBOutlet weak var artistToTitleLargeDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomControlToProgressDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var playerOptionsControlGroupToPlayDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var artworkWidthConstraint: NSLayoutConstraint!
    private var infoCompactToArtworkDistanceConstraint: NSLayoutConstraint?
    @IBOutlet weak var infoLargeToProgressDistanceConstraint: NSLayoutConstraint!
    private var artworkXPositionConstraint: NSLayoutConstraint?
    @IBOutlet weak var timeSliderToArtworkDistanceConstraint: NSLayoutConstraint!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.displayStyle = appDelegate.persistentStorage.settings.playerDisplayStyle
        self.layoutMargins = PlayerView.margin
        player = appDelegate.player
        player.addNotifier(notifier: self)
    }
    
    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        refreshPlayer()
    }
    
    @IBAction func playButtonPushed(_ sender: Any) {
        player.togglePlay()
        refreshPlayButtonTitle()
    }
    
    @IBAction func previousButtonPushed(_ sender: Any) {
        player.playPreviousOrReplay()
    }
    
    @IBAction func nextButtonPushed(_ sender: Any) {
        player.playNext()
    }
    
    @IBAction func repeatButtonPushed(_ sender: Any) {
        player.repeatMode.switchToNextMode()
        refreshRepeatButton()
    }
    
    @IBAction func shuffleButtonPushed(_ sender: Any) {
        player.isShuffle.toggle()
        refreshShuffleButton()
        rootView?.scrollToNextPlayingRow()
    }
    
    @IBAction func timeSliderChanged(_ sender: Any) {
        if let timeSliderValue = timeSlider?.value {
            player.seek(toSecond: Double(timeSliderValue))
        }
    }

    @IBAction func airplayButtonPushed(_ sender: Any) {
        appDelegate.userStatistics.usedAction(.airplay)
        let rect = CGRect(x: -100, y: 0, width: 0, height: 0)
        let airplayVolume = MPVolumeView(frame: rect)
        airplayVolume.showsVolumeSlider = false
        self.addSubview(airplayVolume)
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        airplayVolume.removeFromSuperview()
    }
    
    @IBAction func optionsPressed(_ sender: Any) {
        self.rootView?.optionsPressed()
    }
    
    @IBAction private func displayPlaylistPressed() {
        appDelegate.userStatistics.usedAction(.changePlayerDisplayStyle)
        displayStyle.switchToNextStyle()
        appDelegate.persistentStorage.settings.playerDisplayStyle = displayStyle
        refreshDisplayPlaylistButton()
        renderAnimation()
    }
    
    @IBAction func titleCompactPressed(_ sender: Any) {
        displayAlbumDetail()
        displayPodcastDetail()
    }
    @IBAction func titleLargePressed(_ sender: Any) {
        displayAlbumDetail()
        displayPodcastDetail()
    }
    @IBAction func artistNameCompactPressed(_ sender: Any) {
        displayArtistDetail()
        displayPodcastDetail()
    }
    @IBAction func artistNameLargePressed(_ sender: Any) {
        displayArtistDetail()
        displayPodcastDetail()
    }
    
    private func displayArtistDetail() {
        if let song = lastDisplayedPlayable?.asSong, let artist = song.artist {
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            self.closePopupPlayerAndDisplayInLibraryTab(view: artistDetailVC)
        }
    }
    
    private func displayAlbumDetail() {
        if let song = lastDisplayedPlayable?.asSong, let album = song.album {
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            self.closePopupPlayerAndDisplayInLibraryTab(view: albumDetailVC)
        }
    }
    
    private func displayPodcastDetail() {
        if let podcastEpisode = lastDisplayedPlayable?.asPodcastEpisode, let podcast = podcastEpisode.podcast {
            let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
            podcastDetailVC.podcast = podcast
            self.closePopupPlayerAndDisplayInLibraryTab(view: podcastDetailVC)
        }
    }
    
    private func closePopupPlayerAndDisplayInLibraryTab(view: UIViewController) {
        if let popupPlayerVC = rootView, let hostingTabBarVC = popupPlayerVC.hostingTabBarVC {
            hostingTabBarVC.closePopup(animated: true, completion: { () in
                if let hostingTabViewControllers = hostingTabBarVC.viewControllers,
                   hostingTabViewControllers.count > 0,
                   let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
                    libraryTabNavVC.pushViewController(view, animated: false)
                    hostingTabBarVC.selectedIndex = 0
                }
            })
        }
    }
    
    private func renderAnimation(animationDuration: TimeInterval = defaultAnimationDuration) {
        if displayStyle == .compact {
            rootView?.scrollToNextPlayingRow()
            renderAnimationSwitchToCompact(animationDuration: animationDuration)
        } else {
            renderAnimationSwitchToLarge(animationDuration: animationDuration)
        }
    }
    
    private func renderAnimationSwitchToCompact(animationDuration: TimeInterval = defaultAnimationDuration) {
        guard let rootView = self.rootView else { return }
        artworkWidthConstraint.constant = 100
        infoLargeToProgressDistanceConstraint.constant = -30
        bottomControlToProgressDistanceConstraint.constant = -20
        playerOptionsControlGroupToPlayDistanceConstraint.constant = -2
        
        self.infoCompactToArtworkDistanceConstraint?.isActive = false
        self.infoCompactToArtworkDistanceConstraint = NSLayoutConstraint(item: self.titleCompactLabel!,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: self.artworkImage,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: UIView.defaultMarginX)
        self.infoCompactToArtworkDistanceConstraint?.isActive = true
        
        self.artworkXPositionConstraint?.isActive = false
        self.artworkXPositionConstraint = NSLayoutConstraint(item: artworkImage!,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: rootView.view,
                           attribute: .leadingMargin,
                           multiplier: 1.0,
                           constant: 0)
        self.artworkXPositionConstraint?.isActive = true
    
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut, animations: ({
            self.titleCompactLabel.alpha = 1
            self.titleCompactButton.isHidden = false
            self.titleLargeLabel.alpha = 0
            self.titleLargeButton.isHidden = true
            self.artistNameCompactLabel.alpha = 1
            self.artistNameCompactButton.isHidden = false
            self.artistNameLargeLabel.alpha = 0
            self.artistNameLargeButton.isHidden = true
        }), completion: nil)
        
        rootView.renderAnimationForCompactPlayer(ofHight: PlayerView.frameHeightCompact, animationDuration: animationDuration)

        UIView.animate(withDuration: animationDuration) {
            self.layoutIfNeeded()
        }
    }
    
    private func renderAnimationSwitchToLarge(animationDuration: TimeInterval = defaultAnimationDuration) {
        guard let rootView = self.rootView else { return }
        infoLargeToProgressDistanceConstraint.constant = CGFloat(30.0)
        bottomControlToProgressDistanceConstraint.constant = titleLargeLabel.frame.height + artistNameLargeLabel.frame.height + artistToTitleLargeDistanceConstraint.constant + infoLargeToProgressDistanceConstraint.constant
        playerOptionsControlGroupToPlayDistanceConstraint.constant = CGFloat(0.0)
        
        let availableRootWidth = rootView.view.frame.size.width - PlayerView.margin.left -  PlayerView.margin.right
        let availableRootHeight = rootView.availableFrameHeightForLargePlayer
        
        var elementsBelowArtworkHeight = timeSliderToArtworkDistanceConstraint.constant
        elementsBelowArtworkHeight += timeSlider.frame.size.height
        elementsBelowArtworkHeight += infoLargeToProgressDistanceConstraint.constant
        elementsBelowArtworkHeight += titleLargeLabel.frame.size.height
        elementsBelowArtworkHeight += artistToTitleLargeDistanceConstraint.constant
        elementsBelowArtworkHeight += artistNameLargeLabel.frame.size.height
        elementsBelowArtworkHeight += playButton.frame.size.height
        elementsBelowArtworkHeight += displayPlaylistButton.frame.size.height
        
        let planedArtworkHeight = availableRootWidth
        let fullLargeHeight = artworkImage.frame.origin.y + planedArtworkHeight + elementsBelowArtworkHeight +  PlayerView.margin.bottom

        // Set artwork size depending on device height
        if availableRootHeight < fullLargeHeight {
            artworkWidthConstraint.constant = availableRootHeight - (fullLargeHeight-planedArtworkHeight)
        } else {
            artworkWidthConstraint.constant = availableRootWidth
        }
        
        self.infoCompactToArtworkDistanceConstraint?.isActive = false
        self.infoCompactToArtworkDistanceConstraint = NSLayoutConstraint(item: titleCompactLabel!,
                           attribute: .leading,
                           relatedBy: .lessThanOrEqual,
                           toItem: artworkImage,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: 0)
        self.infoCompactToArtworkDistanceConstraint?.isActive = true
        
        self.artworkXPositionConstraint?.isActive = false
        self.artworkXPositionConstraint = NSLayoutConstraint(item: artworkImage!,
                           attribute: .centerX,
                           relatedBy: .equal,
                           toItem: rootView.view,
                           attribute: .centerX,
                           multiplier: 1.0,
                           constant: 0)
        self.artworkXPositionConstraint?.isActive = true

        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseIn, animations: ({
            self.titleCompactLabel.alpha = 0
            self.titleCompactButton.isHidden = true
            self.titleLargeLabel.alpha = 1
            self.titleLargeButton.isHidden = false
            self.artistNameCompactLabel.alpha = 0
            self.artistNameCompactButton.isHidden = true
            self.artistNameLargeLabel.alpha = 1
            self.artistNameLargeButton.isHidden = false
        }), completion: nil)
        
        rootView.renderAnimationForLargePlayer(animationDuration: animationDuration)

        UIView.animate(withDuration: animationDuration) {
            self.layoutIfNeeded()
        }
    }
    
    func viewWillAppear(_ animated: Bool) {
        refreshPlayer()
        renderAnimation(animationDuration: TimeInterval(0.0))
        
        titleCompactLabel.leadingBuffer = 0.0
        titleCompactLabel.trailingBuffer = 30.0
        titleCompactLabel.animationDelay = 2.0
        titleCompactLabel.type = .continuous
        titleCompactLabel.speed = .rate(20.0)
        titleCompactLabel.fadeLength = 10.0
        
        titleLargeLabel.leadingBuffer = 0.0
        titleLargeLabel.trailingBuffer = 30.0
        titleLargeLabel.animationDelay = 2.0
        titleLargeLabel.type = .continuous
        titleLargeLabel.speed = .rate(20.0)
        titleLargeLabel.fadeLength = 10.0
        
        artistNameCompactLabel.leadingBuffer = 0.0
        artistNameCompactLabel.trailingBuffer = 30.0
        artistNameCompactLabel.animationDelay = 2.0
        artistNameCompactLabel.type = .continuous
        artistNameCompactLabel.speed = .rate(20.0)
        artistNameCompactLabel.fadeLength = 10.0
        
        artistNameLargeLabel.leadingBuffer = 0.0
        artistNameLargeLabel.trailingBuffer = 30.0
        artistNameLargeLabel.animationDelay = 2.0
        artistNameLargeLabel.type = .continuous
        artistNameLargeLabel.speed = .rate(20.0)
        artistNameLargeLabel.fadeLength = 10.0
        
        timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
    }
    
    func refreshPlayButtonTitle() {
        var title = ""
        var buttonImg = UIImage()
        if player.isPlaying {
            title = FontAwesomeIcon.Pause.asString
            buttonImg = UIImage(named: "pause")!
        } else {
            title = FontAwesomeIcon.Play.asString
            buttonImg = UIImage(named: "play")!
        }
        
        playButton.setTitle(title, for: UIControl.State.normal)
        let barButtonItem = UIBarButtonItem(image: buttonImg, style: .plain, target: self, action: #selector(PlayerView.playButtonPushed))
        rootView?.popupItem.trailingBarButtonItems = [ barButtonItem ]
    }
    
    func refreshCurrentlyPlayingInfo() {
        if player.playlist.playables.count > 0 {
            let playableIndex = player.currentlyPlaying?.index ?? 0
            let playableInfo = player.playlist.playables[playableIndex]
            titleCompactLabel.text = playableInfo.title
            titleLargeLabel.text = playableInfo.title
            artistNameCompactLabel.text = playableInfo.creatorName
            artistNameLargeLabel.text = playableInfo.creatorName
            artworkImage.image = playableInfo.image
            rootView?.popupItem.title = playableInfo.title
            rootView?.popupItem.subtitle = playableInfo.creatorName
            rootView?.popupItem.image = playableInfo.image
            rootView?.changeBackgroundGradient(forPlayable: playableInfo)
            lastDisplayedPlayable = playableInfo
        } else {
            titleCompactLabel.text = "Not playing"
            titleLargeLabel.text = "Not playing"
            artistNameCompactLabel.text = ""
            artistNameLargeLabel.text = ""
            artworkImage.image = Artwork.defaultImage
            rootView?.popupItem.title = "Not playing"
            rootView?.popupItem.subtitle = ""
            rootView?.popupItem.image = Artwork.defaultImage
            lastDisplayedPlayable = nil
        }
    }

    func refreshTimeInfo() {
        if player.currentlyPlaying != nil {
            let elapsedClockTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
            elapsedTimeLabel.text = elapsedClockTime.asShortString()
            let remainingTime = ClockTime(timeInSeconds: Int(player.elapsedTime - ceil(player.duration)))
            remainingTimeLabel.text = remainingTime.asShortString()
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = Float(player.duration)
            if !timeSlider.isTouchInside {
                timeSlider.value = Float(player.elapsedTime)
            }
            rootView?.popupItem.progress = Float(player.elapsedTime / player.duration)
        } else {
            elapsedTimeLabel.text = "--:--"
            remainingTimeLabel.text = "--:--"
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = 1.0
            timeSlider.value = 0.0
            rootView?.popupItem.progress = 0.0
        }
    }
    
    func refreshPlayer() {
        refreshCurrentlyPlayingInfo()
        refreshPlayButtonTitle()
        refreshTimeInfo()
        refreshRepeatButton()
        refreshShuffleButton()
        refreshDisplayPlaylistButton()
    }
    
    func refreshRepeatButton() {
        switch player.repeatMode {
        case .off:
            repeatButton.setTitle(FontAwesomeIcon.Redo.asString, for: UIControl.State.normal)
            repeatButton.isSelected = false
        case .all:
            repeatButton.setTitle(FontAwesomeIcon.Redo.asString + " all", for: UIControl.State.selected)
            repeatButton.isSelected = true
        case .single:
            repeatButton.setTitle(FontAwesomeIcon.Redo.asString + " 1", for: UIControl.State.selected)
            repeatButton.isSelected = true
        }
    }
    
    func refreshShuffleButton() {
        if player.isShuffle {
            shuffleButton.isSelected = true
        } else {
            shuffleButton.isSelected = false
        }
    }
    
    func refreshDisplayPlaylistButton() {
        if displayStyle == .compact {
            displayPlaylistButton.tintColor = .defaultBlue
        } else {
            displayPlaylistButton.tintColor = .labelColor
        }
    }
    
}

extension PlayerView: MusicPlayable {

    func didStartPlaying(playlistItem: PlaylistItem) {
        refreshPlayer()
    }
    
    func didPause() {
        refreshPlayer()
    }
    
    func didStopPlaying(playlistItem: PlaylistItem?) {
        refreshPlayer()
        refreshCurrentlyPlayingInfo()
    }

    func didElapsedTimeChange() {
        refreshTimeInfo()
    }
    
    func didPlaylistChange() {
        refreshPlayer()
    }

}
