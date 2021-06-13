import Foundation
import UIKit

class SettingsSongActionOnTabVC: UITableViewController {
    
    var appDelegate: AppDelegate!

    @IBOutlet weak var playAndErasePlaylistButton: UIButton!
    @IBOutlet weak var playAndErasePlaylistCheckLabel: UILabel!
    @IBOutlet weak var addToPlaylistAndPlayButton: UIButton!
    @IBOutlet weak var addToPlaylistAndPlayCheckLabel: UILabel!
    @IBOutlet weak var insertAsNextSongNoPlayButton: UIButton!
    @IBOutlet weak var insertAsNextSongNoPlayCheckLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsPlayerSongTab)

        let settings = appDelegate.persistentStorage.getSettings()

        playAndErasePlaylistButton.setAttributedTitle(NSMutableAttributedString(string: SongActionOnTab.playAndErasePlaylist.displayText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]),  for: .normal)
        addToPlaylistAndPlayButton.setAttributedTitle(NSMutableAttributedString(string: SongActionOnTab.addToPlaylistAndPlay.displayText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]), for: .normal)
        insertAsNextSongNoPlayButton.setAttributedTitle(NSMutableAttributedString(string: SongActionOnTab.insertAsNextSongNoPlay.displayText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]), for: .normal)

        let checkIconText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString + " " , attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
        playAndErasePlaylistCheckLabel.text = ""
        addToPlaylistAndPlayCheckLabel.text = ""
        insertAsNextSongNoPlayCheckLabel.text = ""
        switch settings.songActionOnTab {
        case .playAndErasePlaylist:
            playAndErasePlaylistCheckLabel.attributedText = checkIconText
        case .hiddenOptionPlayInPopupPlayerPlaylistSelectedSong:
            break
        case .addToPlaylistAndPlay:
            addToPlaylistAndPlayCheckLabel.attributedText = checkIconText
        case .insertAsNextSongNoPlay:
            insertAsNextSongNoPlayCheckLabel.attributedText = checkIconText
        }
    }
    
    @IBAction func playAndErasePlaylistPressed(_ sender: Any) {
        let settings = appDelegate.persistentStorage.getSettings()
        settings.songActionOnTab = .playAndErasePlaylist
        appDelegate.persistentStorage.saveSettings(settings: settings)
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func addToPlaylistAndPlayPressed(_ sender: Any) {
        let settings = appDelegate.persistentStorage.getSettings()
        settings.songActionOnTab = .addToPlaylistAndPlay
        appDelegate.persistentStorage.saveSettings(settings: settings)
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func insertAsNextSongNoPlayPressed(_ sender: Any) {
        let settings = appDelegate.persistentStorage.getSettings()
        settings.songActionOnTab = .insertAsNextSongNoPlay
        appDelegate.persistentStorage.saveSettings(settings: settings)
        navigationController?.popToRootViewController(animated: true)
    }

}
