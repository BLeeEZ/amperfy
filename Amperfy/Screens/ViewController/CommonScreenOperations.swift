//
//  CommonScreenOperations.swift
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
import Foundation
import UIKit

extension UIView {
  static let defaultMarginX: CGFloat = 25
  static let defaultMarginY: CGFloat = 11
  static let defaultMarginTopElement = UIEdgeInsets(
    top: 0.0,
    left: UIView.defaultMarginX,
    bottom: 0.0,
    right: UIView.defaultMarginX
  )
  static let defaultMarginMiddleElement = UIEdgeInsets(
    top: UIView.defaultMarginY,
    left: UIView.defaultMarginX,
    bottom: UIView.defaultMarginY,
    right: UIView.defaultMarginX
  )
  static let defaultMarginCellX: CGFloat = 16
  static let defaultMarginCellY: CGFloat = 9
  static let defaultMarginCell = UIEdgeInsets(
    top: UIView.defaultMarginCellY,
    left: UIView.defaultMarginCellX,
    bottom: UIView.defaultMarginCellY,
    right: UIView.defaultMarginCellX
  )
}

// MARK: - CommonScreenOperations

class CommonScreenOperations {
  static let tableSectionHeightLarge: CGFloat = 40
  static let tableSectionHeightFooter: CGFloat = 8
}

// MARK: - UIViewController

extension UIViewController {
  private func createUserButtonMenu() -> UIMenu {
    var accountActions = [UIMenuElement]()
    for accountInfo in appDelegate.storage.settings.accounts.allAccounts {
      let isActiveAccount = (accountInfo == appDelegate.storage.settings.accounts.active)
      let action = UIAction(
        title: appDelegate.storage.settings.accounts.getSetting(accountInfo).read
          .loginCredentials?
          .username ?? "Unknown",
        subtitle: appDelegate.storage.settings.accounts.getSetting(accountInfo).read
          .loginCredentials?
          .displayServerUrl ?? "",
        image: .userCircle(withConfiguration: UIImage.SymbolConfiguration(
          pointSize: 30,
          weight: .regular
        )),
        attributes: isActiveAccount ? [UIMenuElement.Attributes.disabled] : [],
        state: isActiveAccount ? .on : .off,
        handler: { _ in
          self.appDelegate.switchAccount(accountInfo: accountInfo)
        }
      )
      accountActions.append(action)
    }

    #if targetEnvironment(macCatalyst)
      let addAccountImage = UIImage.plus
    #else
      let addAccountImage = UIImage.userCirclePlus
    #endif
    let openAddAccount = UIAction(
      title: "Add Account",
      image: addAccountImage,
      handler: { _ in
        let loginVC = AppStoryboard.Main.segueToLogin()
        loginVC.modalPresentationStyle = .formSheet
        self.present(loginVC, animated: true)
      }
    )
    let openSettings = UIAction(
      title: "Settings",
      image: .settings,
      handler: { _ in
        #if targetEnvironment(macCatalyst)
          self.appDelegate.showSettings(sender: "")
        #else
          let nav = AppStoryboard.Main.segueToSettings()
          nav.modalPresentationStyle = .formSheet
          self.present(nav, animated: true)
        #endif
      }
    )
    let settingsMenu = UIMenu(options: [.displayInline], children: [openAddAccount, openSettings])
    accountActions.append(settingsMenu)

    return UIMenu(
      title: "",
      image: nil,
      options: [.displayInline],
      children: accountActions
    )
  }

  public func setupUserNavButton(
    currentAccount: Account,
    userButton: inout UIButton?,
    userBarButtonItem: inout UIBarButtonItem?
  ) {
    let image = UIImage.userCircle(withConfiguration: UIImage.SymbolConfiguration(
      pointSize: 24,
      weight: .regular
    )).withTintColor(
      appDelegate.storage.settings.accounts.getSetting(currentAccount.info).read
        .themePreference.asColor,
      renderingMode: .alwaysTemplate
    )

    let button = UIButton(type: .system)
    button.setImage(image, for: .normal)
    button.layer.cornerRadius = 20
    button.clipsToBounds = true
    #if targetEnvironment(macCatalyst)
      button.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    #else
      button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    #endif
    button.menu = createUserButtonMenu()
    button.showsMenuAsPrimaryAction = true
    userButton = button

    userBarButtonItem = UIBarButtonItem(customView: button)
    navigationItem.leftBarButtonItem = userBarButtonItem!
  }
}
