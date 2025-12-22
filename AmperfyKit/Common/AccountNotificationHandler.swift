//
//  AccountNotificationHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 22.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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
import UserNotifications

public typealias AccountEventCallback = (AccountInfo) -> ()
public typealias AccountChangedCallback = (AccountInfo?) -> ()

// MARK: - AccountNotificationHandler

@MainActor
public class AccountNotificationHandler {
  private let storage: PersistentStorage
  private let notificationHandler: EventNotificationHandler
  private var accountAddedCB: AccountEventCallback?
  private var activeAccountChangedCB: AccountChangedCallback?
  private var registeredAccounts = Set<AccountInfo>()

  public init(
    storage: PersistentStorage,
    notificationHandler: EventNotificationHandler,

  ) {
    self.storage = storage
    self.notificationHandler = notificationHandler
  }

  public func registerCallbackForAllAccounts(callback: @escaping AccountEventCallback) {
    accountAddedCB = callback

    notificationHandler.register(
      self,
      selector: #selector(reactToNewAccount),
      name: .accountAdded,
      object: nil
    )
    notificationHandler.register(
      self,
      selector: #selector(reactToAccountDeleted),
      name: .accountDeleted,
      object: nil
    )

    reactToNewAccount()
  }

  public func performOnAllRegisteredAccounts(callback: @escaping AccountEventCallback) {
    for accountInfo in registeredAccounts {
      callback(accountInfo)
    }
  }

  @objc
  private func reactToNewAccount() {
    let allAccounts = Set(storage.settings.accounts.allAccounts)
    let notYetRegisterd = allAccounts.subtracting(registeredAccounts)
    for newAccount in notYetRegisterd {
      registeredAccounts.insert(newAccount)
      accountAddedCB?(newAccount)
    }
  }

  @objc
  private func reactToAccountDeleted() {
    let allAccounts = Set(storage.settings.accounts.allAccounts)
    let deletedAccounts = registeredAccounts.subtracting(allAccounts)
    for deletedAccount in deletedAccounts {
      registeredAccounts.remove(deletedAccount)
    }
  }

  public func registerCallbackForActiveAccountChange(callback: @escaping AccountChangedCallback) {
    activeAccountChangedCB = callback
    notificationHandler.register(
      self,
      selector: #selector(reactToActiveAccountChanged),
      name: .accountActiveChanged,
      object: nil
    )
    reactToActiveAccountChanged()
  }

  @objc
  private func reactToActiveAccountChanged() {
    activeAccountChangedCB?(storage.settings.accounts.active)
  }
}
