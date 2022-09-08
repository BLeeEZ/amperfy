//
//  SettingsServerVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 17.02.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import AmperfyKit
import PromiseKit

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
                firstly {
                    self.appDelegate.backendProxy.isAuthenticationValid(credentials: loginCredentials)
                }.done {
                    self.appDelegate.persistentStorage.loginCredentials = loginCredentials
                    self.appDelegate.backendProxy.provideCredentials(credentials: loginCredentials)
                    let alert = UIAlertController(title: "Successful", message: "Password updated!", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Close", style: .default))
                    alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                    self.present(alert, animated: true)
                }.catch { error in
                    let alert = UIAlertController(title: "Failed", message: "Authentication failed! Password has not been updated.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Close", style: .default))
                    alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                    self.present(alert, animated: true)
                }
            }
        }))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }

}
