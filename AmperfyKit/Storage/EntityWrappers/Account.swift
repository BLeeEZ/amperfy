//
//  Account.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 28.11.25.
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

import CoreData
import CryptoKit
import Foundation

// MARK: - AccountInfo

public struct AccountInfo: Sendable, Hashable {
  let serverHash: String
  let userHash: String
  let apiType: BackenApiType

  static let defaultIdent = "0-0"
  static let defaultAccountInfo = AccountInfo(
    serverHash: "",
    userHash: "",
    apiType: .notDetected
  )

  public static func create(basedOnIdent ident: String) -> AccountInfo? {
    let parts = ident.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
    if parts.count == 2 {
      let server = String(parts[0])
      let user = String(parts[1])
      if server == "0", user == "0" {
        return Self.defaultAccountInfo
      } else {
        return AccountInfo(serverHash: server, userHash: user, apiType: .notDetected)
      }
    } else {
      return nil
    }
  }
}

// MARK: - Account

public class Account: NSObject {
  public let managedObject: AccountMO

  public init(managedObject: AccountMO) {
    self.managedObject = managedObject
    super.init()
  }

  func assignAccount(serverUrl: String, userName: String, apiType: BackenApiType) {
    managedObject.serverUrl = serverUrl
    managedObject.userName = userName

    let info = Self.createInfo(serverUrl: serverUrl, userName: userName, apiType: apiType)
    assignInfo(info: info)
  }

  func assignInfo(info: AccountInfo) {
    managedObject.serverHash = info.serverHash
    managedObject.userHash = info.userHash
    managedObject.apiType = Int16(clamping: info.apiType.rawValue)
  }

  public static func createInfo(
    serverUrl: String,
    userName: String,
    apiType: BackenApiType
  )
    -> AccountInfo {
    // Convert String → Data → SHA256 digest
    let serverHashData = SHA256.hash(data: serverUrl.data(using: .utf8)!)
    // Take the first 16 bytes (128 bits) for a shorter name, convert digest to hex string
    let serverHash = serverHashData.prefix(8).compactMap { String(format: "%02hhx", $0) }.joined()
    // Convert String → Data → SHA256 digest
    let userHashData = SHA256.hash(data: userName.data(using: .utf8)!)
    // Take the first 16 bytes (128 bits) for a shorter name, convert digest to hex string
    let userHash = userHashData.prefix(8).compactMap { String(format: "%02hhx", $0) }.joined()
    return AccountInfo(serverHash: serverHash, userHash: userHash, apiType: apiType)
  }

  public static func createInfo(credentials: LoginCredentials) -> AccountInfo {
    Self.createInfo(
      serverUrl: credentials.serverUrl,
      userName: credentials.username,
      apiType: credentials.backendApi
    )
  }

  public var id: String {
    managedObject.id ?? ""
  }

  public var ident: String {
    "\(serverHash)-\(userHash)"
  }

  public var apiType: BackenApiType {
    BackenApiType(rawValue: Int(managedObject.apiType)) ?? .notDetected
  }

  public var serverHash: String {
    managedObject.serverHash ?? ""
  }

  public var serverUrl: String {
    managedObject.serverUrl ?? ""
  }

  public var userHash: String {
    managedObject.userHash ?? ""
  }

  public var userName: String {
    managedObject.userName ?? ""
  }

  public var info: AccountInfo {
    AccountInfo(serverHash: serverHash, userHash: userHash, apiType: apiType)
  }
}
