//
//  GenreParserDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.04.21.
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
import os.log
import UIKit

class GenreParserDelegate: AmpacheXmlLibParser {
  var genreBuffer: Genre?

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

    if elementName == "genre" {
      guard let genreId = attributeDict["id"] else {
        os_log("Found genre with no id", log: log, type: .error)
        return
      }
      if let prefetchedGenre = prefetch.prefetchedGenreDict[genreId] {
        genreBuffer = prefetchedGenre
      } else {
        genreBuffer = library.createGenre(account: account)
        genreBuffer?.id = genreId
        prefetch.prefetchedGenreDict[genreId] = genreBuffer
      }
    }
  }

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    switch elementName {
    case "name":
      genreBuffer?.name = buffer
    case "genre":
      parsedCount += 1
      parseNotifier?.notifyParsedObject(ofType: .genre)
      genreBuffer = nil
    default:
      break
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
