import UIKit
import MediaPlayer

class PlayerVC: UIViewController {
    
    var appDelegate: AppDelegate!
    var player: Player!
 
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var shuffelButton: UIButton!
    @IBOutlet weak var currentSongTimeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
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
    
    @IBAction func shuffelButtonPushed(_ sender: Any) {
        player.isShuffel.toggle()
        refreshShuffelButton()
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
        self.view.addSubview(airplayVolume)
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        airplayVolume.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        player = appDelegate.player
        player.addNotifier(notifier: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshPlayer()
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
        let barButtonItem = UIBarButtonItem(image: buttonImg, style: .plain, target: self, action: #selector(PlayerVC.playButtonPushed))
        popupItem.rightBarButtonItems = [ barButtonItem ]
    }
    
    func refreshSongInfo(song: Song? = nil) {
        if let songInfo = song {
            songTitleLabel.text = songInfo.title
            artistNameLabel.text = songInfo.artist?.name
            artworkImage.image = songInfo.image
            popupItem.title = songInfo.title
            popupItem.subtitle = songInfo.artist?.name
            popupItem.image = songInfo.image
        } else {
            songTitleLabel.text = ""
            artistNameLabel.text = ""
            artworkImage.image = Artwork.defaultImage
            popupItem.title = "No song playing"
            popupItem.subtitle = ""
            popupItem.image = Artwork.defaultImage
        }
    }

    func refreshSongTime() {
        let elapsedTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
        elapsedTimeLabel.text = elapsedTime.asShortString()
        let playerDuration = player.duration.isFinite ? player.duration : 0.0
        let remainingTime = ClockTime(timeInSeconds: Int(player.elapsedTime - ceil(playerDuration)))
        remainingTimeLabel.text = remainingTime.asShortString()
        currentSongTimeSlider.minimumValue = 0.0
        currentSongTimeSlider.maximumValue = Float(player.duration)
        currentSongTimeSlider.value = Float(player.elapsedTime)
        popupItem.progress = Float(player.elapsedTime / player.duration)
    }
    
    func refreshPlayer() {
        refreshSongInfo(song: player.currentlyPlaying?.song)
        refreshPlayButtonTitle()
        refreshSongTime()
        refreshRepeatButton()
        refreshShuffelButton()
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
    
    func refreshShuffelButton() {
        if player.isShuffel {
            shuffelButton.isSelected = true
        } else {
            shuffelButton.isSelected = false
        }
    }
    
}

extension PlayerVC: MusicPlayable {

    func didStartedPlaying(playlistElement: PlaylistElement) {
        refreshPlayer()
    }
    
    func didStartedPausing() {
        refreshPlayer()
    }
    
    func didStopped(playlistElement: PlaylistElement?) {
        refreshPlayer()
    }

    func didElapsedTimeChanged() {
        refreshSongTime()
    }

}
