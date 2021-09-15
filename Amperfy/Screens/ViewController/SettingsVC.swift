import Foundation
import UIKit

class SettingsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildNumberLabel: UILabel!
    @IBOutlet weak var offlineModeSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        versionLabel.text = AppDelegate.version
        buildNumberLabel.text = AppDelegate.buildNumber
        offlineModeSwitch.isOn = appDelegate.persistentStorage.settings.isOfflineMode
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.settings)
    }
    
    @IBAction func triggeredOfflineModeSwitch(_ sender: Any) {
        appDelegate.persistentStorage.settings.isOfflineMode = offlineModeSwitch.isOn
        appDelegate.player.isOfflineMode = offlineModeSwitch.isOn
    }
    
    @IBAction func resetAppPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Reset app data", message: "Are you sure to reset app data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.artworkDownloadManager.stopAndWait()
            self.appDelegate.playableDownloadManager.stopAndWait()
            self.appDelegate.persistentStorage.context.reset()
            self.appDelegate.persistentStorage.loginCredentials = nil
            self.appDelegate.library.cleanStorage()
            self.appDelegate.persistentStorage.isLibrarySyncInfoReadByUser = false
            self.appDelegate.persistentStorage.isLibrarySynced = false
            self.deleteViewControllerCaches()
            self.appDelegate.reinit()
            self.performSegue(withIdentifier: Segues.toLogin.rawValue, sender: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
    private func deleteViewControllerCaches() {
        ArtistFetchedResultsController.deleteCache()
        AlbumFetchedResultsController.deleteCache()
        SongFetchedResultsController.deleteCache()
        PlaylistFetchedResultsController.deleteCache()
        GenreFetchedResultsController.deleteCache()
        PlaylistSelectorFetchedResultsController.deleteCache()
        MusicFolderFetchedResultsController.deleteCache()
        PodcastFetchedResultsController.deleteCache()
    }
    
}
