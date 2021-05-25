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
        if cell == genreTableViewCell, appDelegate.storage.librarySyncVersion < .v7 {
            return 0
        } else if cell == directoriesTableViewCell, appDelegate.backendProxy.selectedApi == .ampache {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
