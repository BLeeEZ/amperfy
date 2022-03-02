import UIKit

extension String {
    var isHyperTextProtocolProvided: Bool {
        return hasPrefix("https://") || hasPrefix("http://")
    }
}

class LoginVC: UIViewController {

    var appDelegate: AppDelegate!
    var backendApi: BackendApi!
    var selectedApiType: BackenApiType = .notDetected
    
    @IBOutlet weak var serverUrlTF: UITextField!
    @IBOutlet weak var usernameTF: UITextField!
    @IBOutlet weak var passwordTF: UITextField!
    @IBOutlet weak var apiSelectorButton: BasicButton!
    
    @IBAction func serverUrlActionPressed() {
        serverUrlTF.resignFirstResponder()
        login()
    }
    @IBAction func usernameActionPressed() {
        usernameTF.resignFirstResponder()
        login()
    }
    @IBAction func passwordActionPressed() {
        passwordTF.resignFirstResponder()
        login()
    }
    @IBAction func loginPressed() {
        serverUrlTF.resignFirstResponder()
        usernameTF.resignFirstResponder()
        passwordTF.resignFirstResponder()
        login()
    }
    @IBAction func apiSelectorPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Select API", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: BackenApiType.notDetected.selectorDescription, style: .default, handler: { _ in
            self.selectedApiType = .notDetected
            self.updateApiSelectorText()
        }))
        alert.addAction(UIAlertAction(title: BackenApiType.ampache.selectorDescription, style: .default, handler: { _ in
            self.selectedApiType = .ampache
            self.updateApiSelectorText()
        }))
        alert.addAction(UIAlertAction(title: BackenApiType.subsonic.selectorDescription, style: .default, handler: { _ in
            self.selectedApiType = .subsonic
            self.updateApiSelectorText()
        }))
        alert.addAction(UIAlertAction(title: BackenApiType.subsonic_legacy.selectorDescription, style: .default, handler: { _ in
            self.selectedApiType = .subsonic_legacy
            self.updateApiSelectorText()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true, completion: nil)
    }
    
    func login() {
        guard let serverUrl = serverUrlTF.text?.trimmingCharacters(in: .whitespacesAndNewlines), !serverUrl.isEmpty else {
            showErrorMsg(message: "No server URL given!")
            return
        }
        guard serverUrl.isHyperTextProtocolProvided else {
            showErrorMsg(message: "Please provide either 'https://' or 'http://' in your server URL.")
            return
        }
        guard let username = usernameTF.text, !username.isEmpty else {
            showErrorMsg(message: "No username given!")
            return
        }
        guard let password = passwordTF.text, !password.isEmpty else {
            showErrorMsg(message: "No password given!")
            return
        }

        let credentials = LoginCredentials(serverUrl: serverUrl, username: username, password: password)
        do {
            let authenticatedApi = try appDelegate.backendProxy.login(apiType: selectedApiType,credentials: credentials)
            credentials.backendApi = authenticatedApi
            appDelegate.persistentStorage.loginCredentials = credentials
            performSegue(withIdentifier: "toSync", sender: self)
        } catch let e as AuthenticationError {
            switch e.kind {
            case .notAbleToLogin:
                showErrorMsg(message: "Not able to login, please check credentials!")
            case .invalidUrl:
                showErrorMsg(message: "Server URL is invalid!")
            case .requestStatusError:
                showErrorMsg(message: "Requesting server URL finished with status response error code '\(e.message)'!")
            case .downloadError:
                showErrorMsg(message: e.message)
            }
        } catch {
            showErrorMsg(message: "Not able to login!")
        }
    }

    func showErrorMsg(message: String) {
        let alert = UIAlertController(title: "Login failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        backendApi = appDelegate.backendApi
        updateApiSelectorText()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let credentials = appDelegate.persistentStorage.loginCredentials {
            serverUrlTF.text = credentials.serverUrl
            usernameTF.text = credentials.username
        }
    }
    
    func updateApiSelectorText() {
        let text = NSMutableAttributedString()
        text.append( NSMutableAttributedString(string: "\(selectedApiType.selectorDescription) ",
            attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17.0),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
        ) )
        text.append( NSMutableAttributedString(string: FontAwesomeIcon.SortDown.asString,
            attributes: [
                NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName,size: 17)!,
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
        ) )
        apiSelectorButton.setAttributedTitle(text, for: .normal)
    }

}
