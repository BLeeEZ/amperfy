//
//  StringHasher.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.03.19.
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

import CryptoKit
import Foundation

class StringHasher {
  static func sha256(dataString: String) -> String {
    let digest = CryptoKit.SHA256.hash(data: dataString.data(using: .utf8) ?? Data())
    return digest.map { String(format: "%02hhx", $0) }.joined()
  }

  private static func md5(dataString: String) -> Data {
    let digest = Insecure.MD5.hash(data: dataString.data(using: .utf8) ?? Data())
    return Data(digest)
  }

  static func md5Hex(dataString: String) -> String {
    md5(dataString: dataString).map { String(format: "%02hhx", $0) }.joined()
  }

  static func md5Base64(dataString: String) -> String {
    md5(dataString: dataString).base64EncodedString()
  }
}
