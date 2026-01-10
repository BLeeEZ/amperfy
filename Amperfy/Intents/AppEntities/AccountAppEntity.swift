//
//  AccountAppEntity.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.12.25.
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

import AmperfyKit
import AppIntents
import Foundation

// MARK: - AccountAppEntity

struct AccountAppEntity: AppEntity, Identifiable {
  static let defaultQuery = AccountEntityQuery()
  static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "Account"
  )

  let id: String
  let serverUrl: String
  let userName: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(userName)",
      subtitle: "\(serverUrl)"
    )
  }
}

// MARK: - AccountEntityQuery

struct AccountEntityQuery: EntityQuery {
  func createAppEntity(
    for credential: LoginCredentials,
    allCredentials credentials: [LoginCredentials]
  )
    -> AccountAppEntity {
    var userName = credential.username
    if credentials.count(where: { $0.username == credential.username }) > 1 {
      userName = userName + " (" + credential.displayServerUrl + ")"
    }
    return AccountAppEntity(
      id: Account.createInfo(credentials: credential).ident,
      serverUrl: credential.displayServerUrl,
      userName: userName
    )
  }

  @MainActor
  func entities(for identifiers: [AccountAppEntity.ID]) async throws -> [AccountAppEntity] {
    let accountInfos = appDelegate.storage.settings.accounts.allAccounts
    let credentials = accountInfos
      .compactMap { appDelegate.storage.settings.accounts.getSetting($0).read.loginCredentials }
    let filteredCredentials = credentials
      .filter { identifiers.contains(Account.createInfo(credentials: $0).ident) }
    return filteredCredentials.map { credential in
      createAppEntity(for: credential, allCredentials: credentials)
    }
  }

  @MainActor
  func suggestedEntities() async throws -> [AccountAppEntity] {
    let accountInfos = appDelegate.storage.settings.accounts.allAccounts
    let credentials = accountInfos
      .compactMap { appDelegate.storage.settings.accounts.getSetting($0).read.loginCredentials }
    return credentials.map { credential in
      createAppEntity(for: credential, allCredentials: credentials)
    }
  }
}
