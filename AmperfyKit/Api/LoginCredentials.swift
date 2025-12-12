//
//  LoginCredentials.swift
//  AmperfyKit
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

import Foundation

public struct LoginCredentials: Sendable, Codable {
  private enum CodingKeys: String, CodingKey {
    case serverUrl
    case username
    case password
    case backendApi
    case activeBackendServerUrl
    case alternativeServerURLs
  }

  public var serverUrl: String
  public var username: String
  public var password: String
  public var passwordHash: String
  public var backendApi: BackenApiType
  public var activeBackendServerUrl: String
  public var alternativeServerURLs: [String]

  public init() {
    self.serverUrl = ""
    self.username = ""
    self.password = ""
    self.passwordHash = ""
    self.backendApi = .notDetected
    self.activeBackendServerUrl = ""
    self.alternativeServerURLs = []
  }

  public var displayServerUrl: String {
    guard let url = URL(string: serverUrl),
          let host = url.host else {
      return ""
    }
    if let port = url.port {
      return "\(host):\(port)"
    }
    return host
  }

  public var availableServerURLs: [String] {
    var availableURLs = alternativeServerURLs
    availableURLs.insert(serverUrl, at: 0)
    return availableURLs
  }

  public init(serverUrl: String, username: String, password: String) {
    self.serverUrl = serverUrl
    self.username = username
    self.password = password
    self.passwordHash = StringHasher.sha256(dataString: password)
    self.backendApi = .notDetected
    self.activeBackendServerUrl = serverUrl
    self.alternativeServerURLs = []
  }

  public init(serverUrl: String, username: String, password: String, backendApi: BackenApiType) {
    self.init(serverUrl: serverUrl, username: username, password: password)
    self.backendApi = backendApi
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.serverUrl = try container.decode(String.self, forKey: .serverUrl)
    self.username = try container.decode(String.self, forKey: .username)
    self.password = try container.decode(String.self, forKey: .password)
    self.backendApi = try container
      .decodeIfPresent(BackenApiType.self, forKey: .backendApi) ?? .notDetected
    self.activeBackendServerUrl = try container.decodeIfPresent(
      String.self,
      forKey: .activeBackendServerUrl
    ) ?? serverUrl
    self.alternativeServerURLs = try container.decodeIfPresent(
      [String].self,
      forKey: .alternativeServerURLs
    ) ?? []
    self.passwordHash = StringHasher.sha256(dataString: password)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(serverUrl, forKey: .serverUrl)
    try container.encode(username, forKey: .username)
    try container.encode(password, forKey: .password)
    try container.encode(backendApi, forKey: .backendApi)
    try container.encode(activeBackendServerUrl, forKey: .activeBackendServerUrl)
    try container.encode(alternativeServerURLs, forKey: .alternativeServerURLs)
  }

  public mutating func changePasswordAndHash(password newPassword: String) {
    password = newPassword
    passwordHash = StringHasher.sha256(dataString: newPassword)
  }
}
