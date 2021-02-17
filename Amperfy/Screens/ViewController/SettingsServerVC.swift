import Foundation
import UIKit

class SettingsServerVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var serverUrlTF: UITextField!
    @IBOutlet weak var usernameTF: UITextField!
    @IBOutlet weak var backendApiLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        if let loginCredentials = self.appDelegate.storage.getLoginCredentials() {
            serverUrlTF.text = loginCredentials.serverUrl
            usernameTF.text = loginCredentials.username
            backendApiLabel.text = loginCredentials.backendApi.description
        }
    }
    
}
