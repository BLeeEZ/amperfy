import Foundation
import UIKit

class SettingsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildNumberLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        versionLabel.text = ""
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionLabel.text = version
        }
        buildNumberLabel.text = ""
        if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            buildNumberLabel.text = buildNumber
        }
    }
    
    @IBAction func issueReportPressed(_ sender: Any) {
        if let url = URL(string: "https://github.com/BLeeEZ/amperfy/issues") {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func resetAppPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Reset app data", message: "Are you sure to reset app data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.downloadManager.stopAndWait()
            self.appDelegate.backgroundSyncerManager.stopAndWait()
            self.appDelegate.storage.deleteLoginCredentials()
            self.appDelegate.persistentLibraryStorage.cleanStorage()
            self.appDelegate.reinit()
            self.performSegue(withIdentifier: Segues.toLogin.rawValue, sender: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
}
