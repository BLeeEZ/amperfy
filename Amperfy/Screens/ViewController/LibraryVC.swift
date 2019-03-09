import Foundation
import UIKit

class LibraryVC: UIViewController {
    
    var settingsButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsPressed))
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    @objc private func settingsPressed() {
        performSegue(withIdentifier: Segues.toSettings.rawValue, sender: nil)
    }
    
}
