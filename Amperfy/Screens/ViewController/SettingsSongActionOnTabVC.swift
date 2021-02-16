import Foundation
import UIKit

class SettingsSongActionOnTabVC: UITableViewController {
    
    var appDelegate: AppDelegate!

    @IBOutlet weak var playAndErasePlaylistButton: UIButton!
    @IBOutlet weak var playAndErasePlaylistCheckLabel: UILabel!
    @IBOutlet weak var addToPlaylistAndPlayButton: UIButton!
    @IBOutlet weak var addToPlaylistAndPlayCheckLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        navigationItem.title = "Action on song tab"
        
        let settings = appDelegate.storage.getSettings()

        addToPlaylistAndPlayButton.setAttributedTitle(NSMutableAttributedString(string: SongActionOnTab.playAndErasePlaylist.description, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]), for: .normal)
        playAndErasePlaylistButton.setAttributedTitle(NSMutableAttributedString(string: SongActionOnTab.addToPlaylistAndPlay.description, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]),  for: .normal)

        let checkIconText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString + " " , attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.VolumeUp.fontName, size: 17)!])
        playAndErasePlaylistCheckLabel.text = ""
        addToPlaylistAndPlayCheckLabel.text = ""
        switch settings.songActionOnTab {
        case .playAndErasePlaylist:
            playAndErasePlaylistCheckLabel.attributedText = checkIconText
        case .addToPlaylistAndPlay:
            addToPlaylistAndPlayCheckLabel.attributedText = checkIconText
        default:
            break
        }
    }
    
    @IBAction func playAndErasePlaylistPressed(_ sender: Any) {
        let settings = appDelegate.storage.getSettings()
        settings.songActionOnTab = .playAndErasePlaylist
        appDelegate.storage.saveSettings(settings: settings)
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func addToPlaylistAndPlayPressed(_ sender: Any) {
        let settings = appDelegate.storage.getSettings()
        settings.songActionOnTab = .addToPlaylistAndPlay
        appDelegate.storage.saveSettings(settings: settings)
        navigationController?.popToRootViewController(animated: true)
    }
    
}
