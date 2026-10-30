//
//  SsDepictionParserDelegate.swift
//  AmperfyKit
//
//  Created by Ziwei Wu on 23.10.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

/// Parses the text of `getArtistInfo2` (`<biography>`) and `getAlbumInfo2` (`<notes>`).
/// The text is kept as the server sent it, which may contain HTML.
class SsDepictionParserDelegate: SsXmlParser {
  public var depiction: String?

  override func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "biography" || elementName == "notes" {
      let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
      depiction = text.isEmpty ? nil : text
    }

    super.parser(
      parser,
      didEndElement: elementName,
      namespaceURI: namespaceURI,
      qualifiedName: qName
    )
  }
}
