import Foundation
import UIKit

class LibraryVC: UITableViewController {
    
    @IBOutlet weak var latestSongAsteriskLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAsteriskStyle()
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
}
