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

extension UITextField {
  func configuteForLogin(image: UIImage) {
    clipsToBounds = true
    layer.cornerRadius = 5
    layer.borderWidth = CGFloat(0.5)
    layer.borderColor = UIColor.label.cgColor

    borderStyle = .roundedRect
    font = .systemFont(ofSize: LoginVC.fontSize)

    let imageView = UIImageView(frame: CGRect(x: 5, y: 0, width: 25, height: 25))
    imageView.contentMode = .scaleAspectFit
    imageView.image = image.withRenderingMode(.alwaysTemplate)
    imageView.tintColor = .label

    let leftContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 35, height: 25))
    leftContainerView.addSubview(imageView)

    leftView = leftContainerView
    leftViewMode = .always

    backgroundColor = .clear
  }
}

// MARK: - LoginVC

class LoginVC: UIViewController {
  var selectedApiType: BackenApiType = .notDetected

  #if targetEnvironment(macCatalyst)
    static let fontSize: CGFloat = 14
  #else
    static let fontSize: CGFloat = 16
  #endif

  fileprivate lazy var iconView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.image = .appIconTemplate
    imageView.tintColor = appDelegate.storage.settings.accounts.getSetting(nil).read.themePreference
      .asColor
    return imageView
  }()

  fileprivate lazy var amperfyLabel: UILabel = {
    let label = UILabel()
    label.text = "Amperfy"
    label.font = .systemFont(ofSize: 50, weight: .bold)
    label.textColor = .tintColor
    label.tintColor = appDelegate.storage.settings.accounts.getSetting(nil).read.themePreference
      .asColor
    return label
  }()

  fileprivate lazy var apiLabel: UILabel = {
    let label = UILabel()
    label.text = "API:"
    label.font = .systemFont(ofSize: Self.fontSize)
    label.textColor = .hardLabelColor
    return label
  }()

  fileprivate lazy var serverUrlTF: UITextField = {
    let textField = UITextField()
    textField.configuteForLogin(image: .serverUrl)
    textField.placeholder = "https://localhost/ampache"
    textField.textContentType = .URL
    textField.keyboardType = .URL
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    textField.addTarget(
      self,
      action: #selector(Self.serverUrlActionPressed),
      for: .primaryActionTriggered
    )
    return textField
  }()

  @IBAction
  func serverUrlActionPressed() {
    serverUrlTF.resignFirstResponder()
    login()
  }

  fileprivate lazy var usernameTF: UITextField = {
    let textField = UITextField()
    textField.configuteForLogin(image: .userPerson)
    textField.placeholder = "Username"
    textField.textContentType = .username
    textField.keyboardType = .default
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    textField.addTarget(
      self,
      action: #selector(Self.usernameActionPressed),
      for: .primaryActionTriggered
    )
    return textField
  }()

  @IBAction
  func usernameActionPressed() {
    usernameTF.resignFirstResponder()
    login()
  }

  fileprivate lazy var passwordTF: UITextField = {
    let textField = UITextField()
    textField.configuteForLogin(image: .password)
    textField.placeholder = "Password"
    textField.textContentType = .password
    textField.keyboardType = .default
    textField.isSecureTextEntry = true
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    textField.addTarget(
      self,
      action: #selector(Self.passwordActionPressed),
      for: .primaryActionTriggered
    )
    return textField
  }()

  @IBAction
  func passwordActionPressed() {
    passwordTF.resignFirstResponder()
    login()
  }

  fileprivate lazy var apiSelectorButton: UIButton = {
    var config = UIButton.Configuration.glass()
    let button = UIButton(configuration: config)
    button.setTitle("API", for: .normal)
    button.preferredBehavioralStyle = .pad
    return button
  }()

  fileprivate lazy var loginButton: UIButton = {
    var config = UIButton.Configuration.prominentGlass()
    config.image = .login
    config.imagePadding = 20.0
    let button = UIButton(configuration: config)
    button.setTitle("Login", for: .normal)
    button.accessibilityLabel = "Login"
    button.addTarget(self, action: #selector(Self.loginPressed), for: .touchUpInside)
    button.preferredBehavioralStyle = .pad
    return button
  }()

  // Close button shown when presented as a sheet/modal
  fileprivate lazy var closeButton: UIButton = {
    var config = UIButton.Configuration.prominentGlass()
    config.image = .xmark
    config.imagePadding = 20.0
    let button = UIButton(configuration: config)
    button.accessibilityLabel = "Close"
    button.addTarget(self, action: #selector(Self.closePressed), for: .touchUpInside)
    button.preferredBehavioralStyle = .pad
    button.isHidden = true
    return button
  }()

  @IBAction
  func closePressed() {
    // Dismiss when presented modally (e.g., as a sheet)
    if presentingViewController != nil || navigationController?.presentingViewController != nil {
      dismiss(animated: true)
    }
  }

  @IBAction
  func loginPressed() {
    serverUrlTF.resignFirstResponder()
    usernameTF.resignFirstResponder()
    passwordTF.resignFirstResponder()
    login()
  }

  public lazy var formView: UIView = {
    self.serverUrlTF.translatesAutoresizingMaskIntoConstraints = false
    self.usernameTF.translatesAutoresizingMaskIntoConstraints = false
    self.passwordTF.translatesAutoresizingMaskIntoConstraints = false
    apiLabel.translatesAutoresizingMaskIntoConstraints = false
    self.apiSelectorButton.translatesAutoresizingMaskIntoConstraints = false

    let view = UIView()
    view.addSubview(serverUrlTF)
    view.addSubview(usernameTF)
    view.addSubview(passwordTF)
    view.addSubview(apiLabel)
    view.addSubview(apiSelectorButton)

    let padding: CGFloat = 0
    let elementHeight: CGFloat = 40
    let spaceInBetween: CGFloat = 15

    NSLayoutConstraint.activate([
      serverUrlTF.safeAreaLayoutGuide.topAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.topAnchor,
        constant: padding
      ),
      serverUrlTF.safeAreaLayoutGuide.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: padding
      ),
      serverUrlTF.safeAreaLayoutGuide.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -padding
      ),
      serverUrlTF.heightAnchor.constraint(equalToConstant: elementHeight),

      usernameTF.safeAreaLayoutGuide.topAnchor.constraint(
        equalTo: serverUrlTF.bottomAnchor,
        constant: spaceInBetween
      ),
      usernameTF.safeAreaLayoutGuide.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: padding
      ),
      usernameTF.safeAreaLayoutGuide.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -padding
      ),
      usernameTF.heightAnchor.constraint(equalToConstant: elementHeight),

      passwordTF.safeAreaLayoutGuide.topAnchor.constraint(
        equalTo: usernameTF.bottomAnchor,
        constant: spaceInBetween
      ),
      passwordTF.safeAreaLayoutGuide.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: padding
      ),
      passwordTF.safeAreaLayoutGuide.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -padding
      ),
      passwordTF.heightAnchor.constraint(equalToConstant: elementHeight),

      apiLabel.safeAreaLayoutGuide.topAnchor.constraint(
        equalTo: passwordTF.bottomAnchor,
        constant: spaceInBetween
      ),
      apiLabel.safeAreaLayoutGuide.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: padding
      ),
      apiLabel.heightAnchor.constraint(equalToConstant: elementHeight),

      apiSelectorButton.safeAreaLayoutGuide.topAnchor.constraint(
        equalTo: passwordTF.bottomAnchor,
        constant: spaceInBetween
      ),
      apiSelectorButton.safeAreaLayoutGuide.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -padding
      ),
      apiSelectorButton.heightAnchor.constraint(equalToConstant: elementHeight),

      view.heightAnchor
        .constraint(equalToConstant: (4 * elementHeight) + (3 * spaceInBetween) + (2 * padding)),
    ])

    return view
  }()

  var mainContainerPaddingLeadingConstraint: NSLayoutConstraint?
  var mainContainerPaddingTrailingConstraint: NSLayoutConstraint?
  var mainContainerPaddingTopConstraint: NSLayoutConstraint?
  var mainContainerPaddingBottomConstraint: NSLayoutConstraint?
  var formLeadingConstraing: NSLayoutConstraint?
  var formTrailingConstraing: NSLayoutConstraint?
  var formWitdhConstraing: NSLayoutConstraint?

  public lazy var mainContainerView: UIView = {
    self.formView.translatesAutoresizingMaskIntoConstraints = false

    let view = UIView()
    view.addSubview(formView)

    let outerInset: CGFloat = 25

    mainContainerPaddingLeadingConstraint = formView.safeAreaLayoutGuide.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: outerInset
    )
    mainContainerPaddingTrailingConstraint = formView.safeAreaLayoutGuide.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -outerInset
    )
    mainContainerPaddingTopConstraint = formView.safeAreaLayoutGuide.topAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.topAnchor,
      constant: outerInset
    )
    mainContainerPaddingBottomConstraint = formView.safeAreaLayoutGuide.bottomAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.bottomAnchor,
      constant: -outerInset
    )

    NSLayoutConstraint.activate([
      mainContainerPaddingLeadingConstraint!,
      mainContainerPaddingTrailingConstraint!,
      mainContainerPaddingTopConstraint!,
      mainContainerPaddingBottomConstraint!,
    ])

    return view
  }()

  public lazy var formGlassContainer: UIVisualEffectView = {
    let container = UIVisualEffectView()
    let glassEffect = UIGlassEffect(style: .regular)
    glassEffect.isInteractive = false
    glassEffect.tintColor = appDelegate.storage.settings.accounts.getSetting(nil).read
      .themePreference.asColor
      .withAlphaComponent(0.1)
    container.effect = glassEffect
    container.cornerConfiguration = .corners(radius: 20)
    mainContainerView.translatesAutoresizingMaskIntoConstraints = false
    container.contentView.addSubview(mainContainerView)

    NSLayoutConstraint.activate([
      container.safeAreaLayoutGuide.topAnchor
        .constraint(equalTo: mainContainerView.safeAreaLayoutGuide.topAnchor),
      container.safeAreaLayoutGuide.leadingAnchor
        .constraint(equalTo: mainContainerView.safeAreaLayoutGuide.leadingAnchor),
      container.safeAreaLayoutGuide.trailingAnchor
        .constraint(equalTo: mainContainerView.safeAreaLayoutGuide.trailingAnchor),
      container.safeAreaLayoutGuide.bottomAnchor
        .constraint(equalTo: mainContainerView.safeAreaLayoutGuide.bottomAnchor),
    ])

    return container
  }()

  public lazy var loginGlassContainer: UIView = {
    loginButton
  }()

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
    var accountInfo = Account.createInfo(credentials: credentials)

    guard !appDelegate.storage.settings.accounts.allAccounts.contains(where: { $0 == accountInfo })
    else {
      showErrorMsg(message: "Account already added!")
      return
    }

    Task { @MainActor in
      do {
        let meta = self.appDelegate.getMeta(accountInfo)
        let authenticatedApiType = try await meta.backendApi.login(
          apiType: selectedApiType,
          credentials: credentials
        )
        credentials.backendApi = authenticatedApiType
        accountInfo = Account.createInfo(credentials: credentials)
        meta.backendApi.selectedApi = authenticatedApiType
        meta.account.assignInfo(info: accountInfo)
        self.appDelegate.storage.main.saveContext()
        self.appDelegate.storage.settings.accounts.login(credentials)
        meta.backendApi.provideCredentials(credentials: credentials)

        self.appDelegate.notificationHandler.post(name: .accountAdded, object: nil, userInfo: nil)
        self.appDelegate.notificationHandler.post(
          name: .accountActiveChanged,
          object: nil,
          userInfo: nil
        )
        AmperfyAppShortcuts.updateAppShortcutParameters()

        let syncVC = AppStoryboard.Main.segueToSync(account: meta.account)
        if let rootVC = presentingViewController {
          syncVC.modalPresentationStyle = self.modalPresentationStyle
          rootVC.dismiss(animated: false) {
            rootVC.present(syncVC, animated: false)
          }
        } else {
          guard let mainScene = AppDelegate.mainSceneDelegate else { return }
          mainScene
            .replaceMainRootViewController(vc: syncVC)
        }
      } catch {
        if error is AuthenticationError {
          self.showErrorMsg(message: error.localizedDescription)
        } else {
          self.showErrorMsg(message: "Not able to login!")
        }
        self.appDelegate.resetMeta(accountInfo)
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

    view.backgroundColor = .systemBackground

    amperfyLabel.translatesAutoresizingMaskIntoConstraints = false
    iconView.translatesAutoresizingMaskIntoConstraints = false
    formGlassContainer.translatesAutoresizingMaskIntoConstraints = false
    loginGlassContainer.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(amperfyLabel)
    view.addSubview(iconView)
    view.addSubview(formGlassContainer)
    view.addSubview(loginGlassContainer)
    view.addSubview(closeButton)

    formLeadingConstraing = formGlassContainer.leadingAnchor.constraint(
      equalTo: view.leadingAnchor,
      constant: 12
    )
    formLeadingConstraing?.priority = .defaultHigh
    formTrailingConstraing = formGlassContainer.trailingAnchor.constraint(
      equalTo: view.trailingAnchor,
      constant: -12
    )
    formTrailingConstraing?.priority = .defaultHigh
    formWitdhConstraing = formGlassContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
    formWitdhConstraing?.priority = .required

    iconView.addConstraint(NSLayoutConstraint(
      item: iconView,
      attribute: .height,
      relatedBy: .equal,
      toItem: iconView,
      attribute: .width,
      multiplier: 1.0,
      constant: 0
    ))
    NSLayoutConstraint.activate([
      amperfyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
      amperfyLabel.bottomAnchor.constraint(equalTo: formGlassContainer.topAnchor, constant: -30),
      amperfyLabel.heightAnchor.constraint(equalToConstant: 60),

      formGlassContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
      formGlassContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0),
      formWitdhConstraing!,
      formLeadingConstraing!,
      formTrailingConstraing!,

      loginGlassContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
      loginGlassContainer.topAnchor.constraint(
        equalTo: formGlassContainer.bottomAnchor,
        constant: 30
      ),
      loginGlassContainer.widthAnchor.constraint(equalToConstant: 140),
      loginGlassContainer.heightAnchor.constraint(equalToConstant: 40),

      iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
      iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0),
      iconView.heightAnchor.constraint(equalTo: formGlassContainer.heightAnchor, constant: 40),

      // Close button top-right
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      closeButton.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -16
      ),
    ])

    // Show close button only when presented as a sheet/modal
    let isModal = presentingViewController != nil || navigationController?
      .presentingViewController != nil
    closeButton.isHidden = !isModal
  }

  override func updateProperties() {
    super.updateProperties()

    var outerInset: CGFloat = 25
    if traitCollection.horizontalSizeClass == .compact {
      outerInset = 20
    } else {
      outerInset = 40
    }

    mainContainerPaddingLeadingConstraint?.constant = outerInset
    mainContainerPaddingTrailingConstraint?.constant = -outerInset
    mainContainerPaddingTopConstraint?.constant = outerInset
    mainContainerPaddingBottomConstraint?.constant = -outerInset + 6
  }

  override func viewWillLayoutSubviews() {
    let glassEffect = UIGlassEffect(style: .regular)
    glassEffect.isInteractive = false
    glassEffect.tintColor = appDelegate.storage.settings.accounts.getSetting(nil).read
      .themePreference.asColor
      .withAlphaComponent(0.1)
    formGlassContainer.effect = glassEffect

    if formGlassContainer.frame.width < 600 {
      formLeadingConstraing?.priority = .required
      formTrailingConstraing?.priority = .required
      formWitdhConstraing?.priority = .defaultHigh
    } else {
      formLeadingConstraing?.priority = .defaultHigh
      formTrailingConstraing?.priority = .defaultHigh
      formWitdhConstraing?.priority = .required
    }
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    if let credentials = appDelegate.storage.settings.accounts.getSetting(nil).read
      .loginCredentials {
      serverUrlTF.text = credentials.serverUrl
      usernameTF.text = credentials.username
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let isModal = presentingViewController != nil || navigationController?
      .presentingViewController != nil
    closeButton.isHidden = !isModal
  }

  func updateApiSelectorText() {
    apiSelectorButton.setTitle("\(selectedApiType.selectorDescription)", for: .normal)
  }
}
