import Foundation
import UIKit

class SettingsArtworkDisplayStyleTableCell: UITableViewCell {
    
    var isActive: Bool = false
    
    @IBOutlet weak var settingLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    func setStatusLabel(isActive: Bool) {
        self.isActive = isActive
        self.statusLabel?.isHidden = !isActive
        self.statusLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
    }
    
}

class SettingsArtworkDisplayStyleVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var settingOptions = [ArtworkDisplayStyle]()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        settingOptions = ArtworkDisplayStyle.allCases
    }
    
    override func viewWillAppear(_ animated: Bool) {
        reload()
    }
    
    func reload() {
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingOptions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingsArtworkDisplayStyleTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.settingLabel.text = settingOptions[indexPath.row].description
        cell.setStatusLabel(isActive: settingOptions[indexPath.row] == appDelegate.persistentStorage.settings.artworkDisplayStyle)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        appDelegate.persistentStorage.settings.artworkDisplayStyle = settingOptions[indexPath.row]
        reload()
    }
    
}
