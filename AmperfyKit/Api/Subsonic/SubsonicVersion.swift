//
//  SubsonicVersion.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.02.21.
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

// MARK: - SubsonicVersion

final class SubsonicVersion: Sendable {
  static let authenticationTokenRequiredServerApi = SubsonicVersion(major: 1, minor: 13, patch: 0)

  let major: Int
  let minor: Int
  let patch: Int

  public var description: String { "\(major).\(minor).\(patch)" }

  init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  convenience init?(_ versionString: String) {
    let splittedVersionString = versionString.components(separatedBy: ".")
    guard splittedVersionString.count == 3 else {
      return nil
    }
    guard let majorInt = Int(splittedVersionString[0]),
          let minorInt = Int(splittedVersionString[1]),
          let patchInt = Int(splittedVersionString[2]),
          majorInt >= 0, minorInt >= 0, patchInt >= 0 else {
      return nil
    }
    self.init(major: majorInt, minor: minorInt, patch: patchInt)
  }
}

extension SubsonicVersion {
  static func == (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
    lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
  }

  static func > (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
    if lhs.major > rhs.major { return true }
    if lhs.minor > rhs.minor { return true }
    if lhs.patch > rhs.patch { return true }
    return false
  }

  static func >= (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
    if lhs == rhs { return true }
    return lhs > rhs
  }

  static func < (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
    if lhs == rhs { return false }
    return !(lhs > rhs)
  }

  static func <= (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
    if lhs == rhs { return true }
    return !(lhs > rhs)
  }
}
