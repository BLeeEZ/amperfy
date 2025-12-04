//
//  SsRadioParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.12.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import os.log
import UIKit

class SsRadioParserDelegate: SsXmlLibParser {
  var radioBuffer: Radio?
  var parsedRadios = [Radio]()

  override func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    if elementName == "internetRadioStation" {
      guard let radioId = attributeDict["id"] else {
        os_log("Found radio with no id", log: log, type: .error)
        return
      }
      if let prefetchedRadio = prefetch.prefetchedRadioDict[radioId] {
        radioBuffer = prefetchedRadio
        radioBuffer?.remoteStatus = .available
      } else {
        radioBuffer = library.createRadio(account: account)
        prefetch.prefetchedRadioDict[radioId] = radioBuffer
        radioBuffer?.id = radioId
      }

      if let attributeTitle = attributeDict["name"] {
        radioBuffer?.title = attributeTitle
      }
      if let streamUrl = attributeDict["streamUrl"] {
        radioBuffer?.url = streamUrl
      }
      if let siteUrl = attributeDict["homePageUrl"] {
        radioBuffer?.siteURL = URL(string: siteUrl)
      }
    }

    super.parser(
      parser,
      didStartElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName,
      attributes: attributeDict
    )
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )

    if elementName == "internetRadioStation", let radio = radioBuffer {
      parsedCount += 1
      parsedRadios.append(radio)
      radioBuffer = nil
    }
  }
}
