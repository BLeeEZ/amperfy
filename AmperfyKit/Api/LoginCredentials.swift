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

public struct LoginCredentials: Sendable {
  public var serverUrl: String
  public var username: String
  public var password: String
  public var passwordHash: String
  public var backendApi: BackenApiType

  public init() {
    self.serverUrl = ""
    self.username = ""
    self.password = ""
    self.passwordHash = ""
    self.backendApi = .notDetected
  }

  public init(serverUrl: String, username: String, password: String) {
    self.serverUrl = serverUrl
    self.username = username
    self.password = password
    self.passwordHash = StringHasher.sha256(dataString: password)
    self.backendApi = .notDetected
  }

  public init(serverUrl: String, username: String, password: String, backendApi: BackenApiType) {
    self.init(serverUrl: serverUrl, username: username, password: password)
    self.backendApi = backendApi
  }

  public mutating func changePasswordAndHash(password newPassword: String) {
    password = newPassword
    passwordHash = StringHasher.sha256(dataString: newPassword)
  }
}
