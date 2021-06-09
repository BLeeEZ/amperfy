import Foundation
import UIKit

class SettingsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildNumberLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        versionLabel.text = AppDelegate.version
        buildNumberLabel.text = AppDelegate.buildNumber
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.settings)
    }
    
    @IBAction func resetAppPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Reset app data", message: "Are you sure to reset app data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.artworkDownloadManager.stopAndWait()
            self.appDelegate.songDownloadManager.stopAndWait()
            self.appDelegate.backgroundSyncerManager.stopAndWait()
            self.appDelegate.storage.context.reset()
            self.appDelegate.storage.deleteLoginCredentials()
            self.appDelegate.persistentLibraryStorage.cleanStorage()
            self.appDelegate.storage.deleteLibraryIsSyncedFlag()
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
    }
    
}
