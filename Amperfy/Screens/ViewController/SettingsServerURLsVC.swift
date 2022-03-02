import Foundation
import UIKit

class ServerURLTableCell: UITableViewCell {
    
    var isActive: Bool = false
    
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    func setStatusLabel(isActiveURL: Bool) {
        self.isActive = isActiveURL
        self.statusLabel?.isHidden = !isActiveURL
        self.statusLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
    }
    
}

class SettingsServerURLsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var serverURLs = [String]()
    var activeServerURL: String =  ""
    private var editButton: UIBarButtonItem!
    private var doneButton: UIBarButtonItem!
    private var urlAddBarButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(startEditing))
        doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(endEditing))
        urlAddBarButton = UIBarButtonItem(image: UIImage.plus, style: .plain, target: self, action: #selector(addUrlPressed))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshBarButtons()
        reload()
    }
    
    func reload() {
        serverURLs = appDelegate.persistentStorage.alternativeServerURLs
        activeServerURL = appDelegate.persistentStorage.loginCredentials?.serverUrl ?? ""
        serverURLs.append(activeServerURL)
        serverURLs.sort()
        tableView.reloadData()
    }
    
    func refreshBarButtons() {
        if tableView.isEditing {
            navigationItem.rightBarButtonItems = [urlAddBarButton, doneButton]
        } else {
            navigationItem.rightBarButtonItems = [urlAddBarButton, editButton]
            
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverURLs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ServerURLTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.urlLabel.text = serverURLs[indexPath.row]
        cell.setStatusLabel(isActiveURL: serverURLs[indexPath.row] == activeServerURL)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard serverURLs[indexPath.row] != activeServerURL else { return }
        if let altIndex = self.appDelegate.persistentStorage.alternativeServerURLs.firstIndex(of: serverURLs[indexPath.row]),
           let currentCredentials = self.appDelegate.persistentStorage.loginCredentials {
            var altURLs = self.appDelegate.persistentStorage.alternativeServerURLs
            altURLs.remove(at: altIndex)
            altURLs.append(currentCredentials.serverUrl)
            self.appDelegate.persistentStorage.alternativeServerURLs = altURLs
            
            let newCredentials = LoginCredentials(serverUrl: serverURLs[indexPath.row], username: currentCredentials.username, password: currentCredentials.password, backendApi: currentCredentials.backendApi)
            self.appDelegate.persistentStorage.loginCredentials = newCredentials
            self.appDelegate.backendProxy.authenticate(credentials: newCredentials)
        }
        reload()
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return serverURLs[indexPath.row] == activeServerURL ? .none : .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard serverURLs[indexPath.row] != activeServerURL else { return }
        if editingStyle == .delete {
            if let altIndex = self.appDelegate.persistentStorage.alternativeServerURLs.firstIndex(of: serverURLs[indexPath.row]) {
                var altURLs = self.appDelegate.persistentStorage.alternativeServerURLs
                altURLs.remove(at: altIndex)
                self.appDelegate.persistentStorage.alternativeServerURLs = altURLs
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .fade)
                serverURLs.remove(at: indexPath.row)
                tableView.endUpdates()
            }
        }
    }
    
    @objc private func startEditing() {
        tableView.isEditing = true
        refreshBarButtons()
    }
    
    @objc private func endEditing() {
        tableView.isEditing = false
        refreshBarButtons()
    }

    @objc private func addUrlPressed() {
        let alert = UIAlertController(title: "Add alternative URL", message: "The URL must reach the same server. Otherwise library inconsistencies will occure.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addTextField(configurationHandler: {urlTextField in
            urlTextField.placeholder = "https://localhost/ampache"
        })
        alert.addTextField(configurationHandler: {textField in
            textField.text = self.appDelegate.persistentStorage.loginCredentials?.username ?? ""
            textField.isEnabled = false
            
        })
        alert.addTextField(configurationHandler: { passwordTextField in
            passwordTextField.placeholder = "Password"
            passwordTextField.isSecureTextEntry = true
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            guard let newAltUrl = alert.textFields?.element(at: 0)?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newAltUrl.isEmpty,
                  !self.serverURLs.contains(where: {$0 == newAltUrl}),
                  let username = alert.textFields?.element(at: 1)?.text,
                  !username.isEmpty,
                  let password = alert.textFields?.element(at: 2)?.text,
                  !password.isEmpty,
                  let activeApi = self.appDelegate.persistentStorage.loginCredentials?.backendApi
            else { return }
            
            guard newAltUrl.isHyperTextProtocolProvided else {
                let alert = UIAlertController(title: "Failed", message: "Please provide either 'https://' or 'http://' in your server URL.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .default))
                alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                self.present(alert, animated: true)
                return
            }
            
            let credentials = LoginCredentials(serverUrl: newAltUrl, username: username, password: password, backendApi: activeApi)

            DispatchQueue.global().async {
                let isValid = self.appDelegate.backendProxy.isAuthenticationValid(credentials: credentials)
                DispatchQueue.main.async {
                    if isValid {
                        if let activeUrl = self.appDelegate.persistentStorage.loginCredentials?.serverUrl {
                            var currentAltUrls = self.appDelegate.persistentStorage.alternativeServerURLs
                            currentAltUrls.append(activeUrl)
                            self.appDelegate.persistentStorage.alternativeServerURLs = currentAltUrls
                        }
                        self.appDelegate.persistentStorage.loginCredentials = credentials
                        self.reload()
    
                        let alert = UIAlertController(title: "Successful", message: "Alternative URL added.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Close", style: .default))
                        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                        self.present(alert, animated: true)
                    } else {
                        let alert = UIAlertController(title: "Failed", message: "Alternative URL could not be verified! Authentication failed! Alternative URL has not been added.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Close", style: .default))
                        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                        self.present(alert, animated: true)
                    }
                }
            }
        }))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }

}
