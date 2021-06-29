import Foundation
import UIKit

class SettingsPlayerVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var autoCachePlayedSongsSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsPlayer)
        
        autoCachePlayedSongsSwitch.isOn = appDelegate.player.isAutoCachePlayedItems
    }

    @IBAction func triggeredAutoCachePlayedSongsSwitch(_ sender: Any) {
        appDelegate.player.isAutoCachePlayedItems = autoCachePlayedSongsSwitch.isOn
    }
}
