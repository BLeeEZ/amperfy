import Foundation
import UIKit

class SettingsServerVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var serverUrlTF: UITextField!
    @IBOutlet weak var usernameTF: UITextField!
    @IBOutlet weak var backendApiLabel: UILabel!
    @IBOutlet weak var serverApiVersionLabel: UILabel!
    @IBOutlet weak var clientApiVersionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsServer)
        
        if let loginCredentials = self.appDelegate.persistentStorage.getLoginCredentials() {
            serverUrlTF.text = loginCredentials.serverUrl
            usernameTF.text = loginCredentials.username
            backendApiLabel.text = loginCredentials.backendApi.description
            serverApiVersionLabel.text = self.appDelegate.backendApi.serverApiVersion
            clientApiVersionLabel.text = self.appDelegate.backendApi.clientApiVersion
        }
    }
    
}
