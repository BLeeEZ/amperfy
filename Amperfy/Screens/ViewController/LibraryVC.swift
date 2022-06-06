import Foundation
import UIKit
import AmperfyKit

class LibraryVC: UITableViewController {
    
    @IBOutlet weak var genreTableViewCell: UITableViewCell!
    @IBOutlet weak var directoriesTableViewCell: UITableViewCell!
    @IBOutlet weak var genreImageButton: UIButton!
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        genreImageButton.imageView?.contentMode = .scaleAspectFit
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.library)
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == genreTableViewCell, appDelegate.persistentStorage.librarySyncVersion < .v7 {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
}
