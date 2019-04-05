import UIKit

class LoginVC: UIViewController {

    var appDelegate: AppDelegate!
    var backendApi: BackendApi!
    
    @IBOutlet weak var serverUrlTF: UITextField!
    @IBOutlet weak var usernameTF: UITextField!
    @IBOutlet weak var passwordTF: UITextField!
    
    @IBAction func loginPressed(_ sender: Any) {
        guard let serverUrl = serverUrlTF.text, !serverUrl.isEmpty else {
            showErrorMsg(message: "No server address given!")
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
            let authenticatedApi = try appDelegate.backendProxy.login(credentials: credentials)
            credentials.backendApi = authenticatedApi
            appDelegate.storage.saveLoginCredentials(credentials: credentials)
            performSegue(withIdentifier: "toSync", sender: self)
        } catch {
            showErrorMsg(message: "Not able to login, please check credentials!")
        }
    }

    func showErrorMsg(message: String) {
        let alert = UIAlertController(title: "Login failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        backendApi = appDelegate.backendApi
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let credentials = appDelegate.storage.getLoginCredentials() {
            serverUrlTF.text = credentials.serverUrl
            usernameTF.text = credentials.username
        }
    }

}
