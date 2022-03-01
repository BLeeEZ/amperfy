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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let loginCredentials = self.appDelegate.persistentStorage.loginCredentials {
            serverUrlTF.text = loginCredentials.serverUrl
            usernameTF.text = loginCredentials.username
            backendApiLabel.text = loginCredentials.backendApi.description
            serverApiVersionLabel.text = self.appDelegate.backendApi.serverApiVersion
            clientApiVersionLabel.text = self.appDelegate.backendApi.clientApiVersion
        }
    }
    
    @IBAction func updatePasswordPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Update Password", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addTextField(configurationHandler: { passwordTextField in
            passwordTextField.placeholder = "Changed account password..."
            passwordTextField.isSecureTextEntry = true
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            if let newPassword = alert.textFields?.first?.text,
               let loginCredentials = self.appDelegate.persistentStorage.loginCredentials {
                loginCredentials.changePasswordAndHash(password: newPassword)
                if self.appDelegate.backendProxy.isAuthenticationValid(credentials: loginCredentials) {
                    self.appDelegate.persistentStorage.loginCredentials = loginCredentials
                    self.appDelegate.backendProxy.authenticate(credentials: loginCredentials)
                    let alert = UIAlertController(title: "Successful", message: "Password updated!", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                    self.present(alert, animated: true)
                } else {
                    let alert = UIAlertController(title: "Failed", message: "Not able to login!", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                    self.present(alert, animated: true)
                }
            }
        }))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }

}
