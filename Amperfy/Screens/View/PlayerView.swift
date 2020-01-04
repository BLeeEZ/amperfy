import UIKit
import MediaPlayer
import MarqueeLabel

class PlayerView: UIView {
  
    static let frameHeight: CGFloat = 305.0
    private var appDelegate: AppDelegate!
    private var player: AmperfyPlayer!
    private var rootView: PopupPlayerVC?
    
    @IBOutlet weak var songTitleLabel: MarqueeLabel!
    @IBOutlet weak var artistNameLabel: MarqueeLabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var currentSongTimeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
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
    
    @IBAction private func playlistOptionsPressed() {
        self.rootView?.optionsPressed()
    }
    
    func viewWillAppear(_ animated: Bool) {
        refreshPlayer()
        
        songTitleLabel.leadingBuffer = 0.0
        songTitleLabel.trailingBuffer = 30.0
        songTitleLabel.animationDelay = 2.0
        songTitleLabel.type = .continuous
        songTitleLabel.speed = .rate(20.0)
        songTitleLabel.fadeLength = 10.0
        
        artistNameLabel.leadingBuffer = 0.0
        artistNameLabel.trailingBuffer = 30.0
        artistNameLabel.animationDelay = 2.0
        artistNameLabel.type = .continuous
        artistNameLabel.speed = .rate(20.0)
        artistNameLabel.fadeLength = 10.0
        
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .lightGray, for: UIControl.State.normal)
        currentSongTimeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .lightGray, for: UIControl.State.highlighted)
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
        rootView?.popupItem.rightBarButtonItems = [ barButtonItem ]
    }
    
    func refreshSongInfo(song: Song? = nil) {
        if let songInfo = song {
            songTitleLabel.text = songInfo.title
            artistNameLabel.text = songInfo.artist?.name
            artworkImage.image = songInfo.image
            rootView?.popupItem.title = songInfo.title
            rootView?.popupItem.subtitle = songInfo.artist?.name
            rootView?.popupItem.image = songInfo.image
        } else {
            songTitleLabel.text = "No song playing"
            artistNameLabel.text = ""
            artworkImage.image = Artwork.defaultImage
            rootView?.popupItem.title = "No song playing"
            rootView?.popupItem.subtitle = ""
            rootView?.popupItem.image = Artwork.defaultImage
        }
    }

    func refreshSongTime() {
        if player.currentlyPlaying != nil {
            let elapsedTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
            elapsedTimeLabel.text = elapsedTime.asShortString()
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
        refreshSongInfo(song: player.currentlyPlaying?.song)
        refreshPlayButtonTitle()
        refreshSongTime()
        refreshRepeatButton()
        refreshShuffleButton()
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
        refreshSongInfo(song: nil)
    }

    func didElapsedTimeChange() {
        refreshSongTime()
    }
    
    func didPlaylistChange() {
        refreshPlayer()
    }

}
