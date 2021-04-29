import Foundation
import UIKit

class LibraryVC: UITableViewController {
    
    @IBOutlet weak var genreTableViewCell: UITableViewCell!
    @IBOutlet weak var latestSongAsteriskLabel: UILabel!
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        configureAsteriskStyle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    func configureAsteriskStyle() {
        latestSongAsteriskLabel.layer.cornerRadius = 6.5
        latestSongAsteriskLabel.layer.masksToBounds = true
        latestSongAsteriskLabel.backgroundColor = UIColor.defaultBlue
        if #available(iOS 13.0, *) {
            latestSongAsteriskLabel.textColor = UIColor.secondarySystemBackground
        } else {
            latestSongAsteriskLabel.textColor = UIColor.white
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if appDelegate.storage.librarySyncVersion < .v7,
           cell == genreTableViewCell {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
