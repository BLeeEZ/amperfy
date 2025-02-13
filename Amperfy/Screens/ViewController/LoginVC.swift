//
//  LoginVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import UIKit

extension String {
  var isHyperTextProtocolProvided: Bool {
    hasPrefix("https://") || hasPrefix("http://")
  }
}

// MARK: - LoginVC

class LoginVC: UIViewController {
  var backendApi: BackendApi!
  var selectedApiType: BackenApiType = .notDetected

  @IBOutlet
  weak var serverUrlTF: UITextField!
  @IBOutlet
  weak var usernameTF: UITextField!
  @IBOutlet
  weak var passwordTF: UITextField!
  @IBOutlet
  weak var apiSelectorButton: BasicButton!

  @IBAction
  func serverUrlActionPressed() {
    serverUrlTF.resignFirstResponder()
    login()
  }

  @IBAction
  func usernameActionPressed() {
    usernameTF.resignFirstResponder()
    login()
  }

  @IBAction
  func passwordActionPressed() {
    passwordTF.resignFirstResponder()
    login()
  }

  @IBAction
  func loginPressed() {
    serverUrlTF.resignFirstResponder()
    usernameTF.resignFirstResponder()
    passwordTF.resignFirstResponder()
    login()
  }

  func login() {
    guard let serverUrl = serverUrlTF.text?.trimmingCharacters(in: .whitespacesAndNewlines),
          !serverUrl.isEmpty else {
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

    var credentials = LoginCredentials(serverUrl: serverUrl, username: username, password: password)
    Task { @MainActor in
      do {
        let authenticatedApiType = try await self.appDelegate.backendApi.login(
          apiType: selectedApiType,
          credentials: credentials
        )
        self.appDelegate.backendApi.selectedApi = authenticatedApiType
        credentials.backendApi = authenticatedApiType
        self.appDelegate.storage.loginCredentials = credentials
        self.appDelegate.backendApi.provideCredentials(credentials: credentials)
        self.performSegue(withIdentifier: "toSync", sender: self)
      } catch {
        if error is AuthenticationError {
          self.showErrorMsg(message: error.localizedDescription)
        } else {
          self.showErrorMsg(message: "Not able to login!")
        }
      }
    }
  }

  func showErrorMsg(message: String) {
    let alert = UIAlertController(title: "Login failed", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true, completion: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    backendApi = appDelegate.backendApi
    updateApiSelectorText()

    apiSelectorButton.showsMenuAsPrimaryAction = true
    apiSelectorButton.menu = UIMenu(title: "Select API", children: [
      UIAction(title: BackenApiType.notDetected.selectorDescription, handler: { _ in
        self.selectedApiType = .notDetected
        self.updateApiSelectorText()
      }),
      UIAction(title: BackenApiType.ampache.selectorDescription, handler: { _ in
        self.selectedApiType = .ampache
        self.updateApiSelectorText()
      }),
      UIAction(title: BackenApiType.subsonic.selectorDescription, handler: { _ in
        self.selectedApiType = .subsonic
        self.updateApiSelectorText()
      }),
      UIAction(title: BackenApiType.subsonic_legacy.selectorDescription, handler: { _ in
        self.selectedApiType = .subsonic_legacy
        self.updateApiSelectorText()
      }),
    ])
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    if let credentials = appDelegate.storage.loginCredentials {
      serverUrlTF.text = credentials.serverUrl
      usernameTF.text = credentials.username
    }
  }

  func updateApiSelectorText() {
    apiSelectorButton.setTitle("\(selectedApiType.selectorDescription)", for: .normal)
  }
}
