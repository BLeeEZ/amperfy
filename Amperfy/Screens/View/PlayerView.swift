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
}

class PlayerView: UIView {
  
    static private let frameHeightCompact: CGFloat = 285 + margin.top + margin.bottom
    static private let margin = UIEdgeInsets(top: 0, left: UIView.defaultMarginX, bottom: 20, right: UIView.defaultMarginX)
    static private let defaultAnimationDuration = TimeInterval(0.50)
    
    var lastDisplayedSong: Song?
    
    private var appDelegate: AppDelegate!
    private var player: MusicPlayer!
    private var rootView: PopupPlayerVC?
    private var displayStyle: PlayerDisplayStyle!
    
    @IBOutlet weak var songTitleCompactLabel: MarqueeLabel!
    @IBOutlet weak var songTitleLargeLabel: MarqueeLabel!
    
    @IBOutlet weak var artistNameCompactLabel: MarqueeLabel!
    @IBOutlet weak var artistNameLargeLabel: MarqueeLabel!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var displayPlaylistButton: UIButton!
    @IBOutlet weak var currentSongTimeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    // Animation constraints
    @IBOutlet weak var artistToSongLargeDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomControlToProgressDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var playerOptionsControlGroupToPlayDistanceConstraint: NSLayoutConstraint!
    @IBOutlet weak var artworkWidthConstraint: NSLayoutConstraint!
    private var songInfoCompactToArtworkDistanceConstraint: NSLayoutConstraint?
    @IBOutlet weak var songInfoLargeToProgressDistanceConstraint: NSLayoutConstraint!
    private var artworkXPositionConstraint: NSLayoutConstraint?
    @IBOutlet weak var songSliderToArtworkDistanceConstraint: NSLayoutConstraint!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.displayStyle = appDelegate.storage.getSettings().playerDisplayStyle
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
    
    @IBAction func currentSongTimeSliderChanged(_ sender: Any) {
        if let timeSliderValue = currentSongTimeSlider?.value {
            player.seek(toSecond: Double(timeSliderValue))
        }
    }

    @IBAction func airplayButtonPushed(_ sender: Any) {
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
        displayStyle.switchToNextStyle()
        let settings = appDelegate.storage.getSettings()
        settings.playerDisplayStyle = displayStyle
        appDelegate.storage.saveSettings(settings: settings)
        refreshDisplayPlaylistButton()
        renderAnimation()
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
        songInfoLargeToProgressDistanceConstraint.constant = -30
        bottomControlToProgressDistanceConstraint.constant = -20
        playerOptionsControlGroupToPlayDistanceConstraint.constant = -2
        
        self.songInfoCompactToArtworkDistanceConstraint?.isActive = false
        self.songInfoCompactToArtworkDistanceConstraint = NSLayoutConstraint(item: self.songTitleCompactLabel!,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: self.artworkImage,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: UIView.defaultMarginX)
        self.songInfoCompactToArtworkDistanceConstraint?.isActive = true
        
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
            self.songTitleCompactLabel.alpha = 1
            self.songTitleLargeLabel.alpha = 0
            self.artistNameCompactLabel.alpha = 1
            self.artistNameLargeLabel.alpha = 0
        }), completion: nil)
        
        rootView.renderAnimationForCompactPlayer(ofHight: PlayerView.frameHeightCompact, animationDuration: animationDuration)

        UIView.animate(withDuration: animationDuration) {
            self.layoutIfNeeded()
        }
    }
    
    private func renderAnimationSwitchToLarge(animationDuration: TimeInterval = defaultAnimationDuration) {
        guard let rootView = self.rootView else { return }
        songInfoLargeToProgressDistanceConstraint.constant = CGFloat(30.0)
        bottomControlToProgressDistanceConstraint.constant = songTitleLargeLabel.frame.height + artistNameLargeLabel.frame.height + artistToSongLargeDistanceConstraint.constant + songInfoLargeToProgressDistanceConstraint.constant
        playerOptionsControlGroupToPlayDistanceConstraint.constant = CGFloat(0.0)
        
        let availableRootWidth = rootView.view.frame.size.width - PlayerView.margin.left -  PlayerView.margin.right
        let availableRootHeight = rootView.availableFrameHeightForLargePlayer
        
        var elementsBelowArtworkHeight = songSliderToArtworkDistanceConstraint.constant
        elementsBelowArtworkHeight += currentSongTimeSlider.frame.size.height
        elementsBelowArtworkHeight += songInfoLargeToProgressDistanceConstraint.constant
        elementsBelowArtworkHeight += songTitleLargeLabel.frame.size.height
        elementsBelowArtworkHeight += artistToSongLargeDistanceConstraint.constant
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
        
        self.songInfoCompactToArtworkDistanceConstraint?.isActive = false
        self.songInfoCompactToArtworkDistanceConstraint = NSLayoutConstraint(item: songTitleCompactLabel!,
                           attribute: .leading,
                           relatedBy: .lessThanOrEqual,
                           toItem: artworkImage,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: 0)
        self.songInfoCompactToArtworkDistanceConstraint?.isActive = true
        
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
            self.songTitleCompactLabel.alpha = 0
            self.songTitleLargeLabel.alpha = 1
            self.artistNameCompactLabel.alpha = 0
            self.artistNameLargeLabel.alpha = 1
        }), completion: nil)
        
        rootView.renderAnimationForLargePlayer(animationDuration: animationDuration)

        UIView.animate(withDuration: animationDuration) {
            self.layoutIfNeeded()
        }
    }
    
    func viewWillAppear(_ animated: Bool) {
        refreshPlayer()
        renderAnimation(animationDuration: TimeInterval(0.0))
        
        songTitleCompactLabel.leadingBuffer = 0.0
        songTitleCompactLabel.trailingBuffer = 30.0
        songTitleCompactLabel.animationDelay = 2.0
        songTitleCompactLabel.type = .continuous
        songTitleCompactLabel.speed = .rate(20.0)
        songTitleCompactLabel.fadeLength = 10.0
        
        songTitleLargeLabel.leadingBuffer = 0.0
        songTitleLargeLabel.trailingBuffer = 30.0
        songTitleLargeLabel.animationDelay = 2.0
        songTitleLargeLabel.type = .continuous
        songTitleLargeLabel.speed = .rate(20.0)
        songTitleLargeLabel.fadeLength = 10.0
        
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
        
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
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
    
    func refreshSongInfo() {
        if player.playlist.songs.count > 0 {
            let songIndex = player.currentlyPlaying?.index ?? 0
            let songInfo = player.playlist.songs[songIndex]
            songTitleCompactLabel.text = songInfo.title
            songTitleLargeLabel.text = songInfo.title
            artistNameCompactLabel.text = songInfo.artist?.name
            artistNameLargeLabel.text = songInfo.artist?.name
            artworkImage.image = songInfo.image
            rootView?.popupItem.title = songInfo.title
            rootView?.popupItem.subtitle = songInfo.artist?.name
            rootView?.popupItem.image = songInfo.image
            rootView?.changeBackgroundGradient(forSong: songInfo)
            lastDisplayedSong = songInfo
        } else {
            songTitleCompactLabel.text = "No song playing"
            songTitleLargeLabel.text = "No song playing"
            artistNameCompactLabel.text = ""
            artistNameLargeLabel.text = ""
            artworkImage.image = Artwork.defaultImage
            rootView?.popupItem.title = "No song playing"
            rootView?.popupItem.subtitle = ""
            rootView?.popupItem.image = Artwork.defaultImage
            lastDisplayedSong = nil
        }
    }

    func refreshSongTime() {
        if player.currentlyPlaying != nil {
            let elapsedTime = player.elapsedTime.isFinite ? Int(player.elapsedTime) : 0
            let elapsedClockTime = ClockTime(timeInSeconds: elapsedTime)
            elapsedTimeLabel.text = elapsedClockTime.asShortString()
            let playerDuration = player.duration.isFinite ? player.duration : 0.0
            let remainingTime = ClockTime(timeInSeconds: Int(player.elapsedTime - ceil(playerDuration)))
            remainingTimeLabel.text = remainingTime.asShortString()
            currentSongTimeSlider.minimumValue = 0.0
            currentSongTimeSlider.maximumValue = Float(player.duration)
            if !currentSongTimeSlider.isTouchInside {
                currentSongTimeSlider.value = Float(player.elapsedTime)
            }
            rootView?.popupItem.progress = Float(player.elapsedTime / player.duration)
        } else {
            elapsedTimeLabel.text = "--:--"
            remainingTimeLabel.text = "--:--"
            currentSongTimeSlider.minimumValue = 0.0
            currentSongTimeSlider.maximumValue = 1.0
            currentSongTimeSlider.value = 0.0
            rootView?.popupItem.progress = 0.0
        }
    }
    
    func refreshPlayer() {
        refreshSongInfo()
        refreshPlayButtonTitle()
        refreshSongTime()
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
        refreshSongInfo()
    }

    func didElapsedTimeChange() {
        refreshSongTime()
    }
    
    func didPlaylistChange() {
        refreshPlayer()
    }

}
