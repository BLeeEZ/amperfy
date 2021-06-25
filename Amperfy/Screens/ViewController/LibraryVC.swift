import Foundation
import UIKit

class LibraryVC: UITableViewController {
    
    @IBOutlet weak var genreTableViewCell: UITableViewCell!
    @IBOutlet weak var directoriesTableViewCell: UITableViewCell!
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.library)
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == genreTableViewCell, appDelegate.persistentStorage.librarySyncVersion < .v7 {
            return 0
        } else if cell == directoriesTableViewCell, appDelegate.backendProxy.selectedApi == .ampache {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    func isSectionHidden(section: Int) -> Bool {
        // Check if podcasts should be hidden
        return (section == 1) && (!appDelegate.backendApi.isPodcastSupported && appDelegate.library.podcastCount == 0)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSectionHidden(section: section) ? 0 : super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSectionHidden(section: section) ? 0.1 : super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return isSectionHidden(section: section) ? 0.1 : super.tableView(tableView, heightForFooterInSection: section)
    }
    
}
