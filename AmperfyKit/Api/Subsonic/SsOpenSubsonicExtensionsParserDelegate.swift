//
//  SsOpenSubsonicExtensionsParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 15.06.24.
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

import CoreData
import Foundation
import UIKit

// MARK: - OpenSubsonicExtensionsResponse

public struct OpenSubsonicExtensionsResponse {
  public var status = ""
  public var version = ""
  public var type = ""
  public var serverVersion = ""
  public var openSubsonic: Bool?
  public var supportedExtensions = [String]()
}

// MARK: - SsOpenSubsonicExtensionsParserDelegate

class SsOpenSubsonicExtensionsParserDelegate: SsXmlParser {
  public var openSubsonicExtensionsResponse = OpenSubsonicExtensionsResponse()

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )

    if elementName == "subsonic-response" {
      openSubsonicExtensionsResponse.status = attributeDict["status"] ?? ""
      openSubsonicExtensionsResponse.version = attributeDict["version"] ?? ""
      openSubsonicExtensionsResponse.type = attributeDict["type"] ?? ""
      openSubsonicExtensionsResponse.serverVersion = attributeDict["serverVersion"] ?? ""
      if let isOpenSubsonic = attributeDict["openSubsonic"] {
        openSubsonicExtensionsResponse.openSubsonic = (isOpenSubsonic == "true")
      } else {
        openSubsonicExtensionsResponse.openSubsonic = false
      }
    } else if elementName == "openSubsonicExtensions" {
      if let name = attributeDict["name"] {
        openSubsonicExtensionsResponse.supportedExtensions.append(name)
      }
    }
  }
}
