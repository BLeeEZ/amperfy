//
//  CaptivePortalDetector.swift
//  AmperfyKit
//
//  Created by Jerzy Królak on 07.05.26.
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

public enum CaptivePortalDetector {
  public static func isCaptivePortalResponse(
    requestURL: URL,
    response: HTTPURLResponse?,
    data: Data?
  )
    -> Bool {
    guard let response else { return false }

    if isDomainRedirect(requestURL: requestURL, response: response) {
      return true
    }

    if isHTMLContentType(response: response) {
      return true
    }

    if response.statusCode == 403, let data, isHTMLContent(data: data) {
      return true
    }

    return false
  }

  public static func isHTMLContent(data: Data) -> Bool {
    let prefix = String(data: data.prefix(500), encoding: .utf8)?.lowercased() ?? ""
    return prefix.contains("<!doctype html") || prefix.contains("<html")
  }

  public static func isDomainRedirect(requestURL: URL, response: HTTPURLResponse?) -> Bool {
    guard let response else { return false }
    guard let responseURL = response.url else { return false }
    guard let requestHost = requestURL.host?.lowercased(),
          let responseHost = responseURL.host?.lowercased()
    else { return false }
    return requestHost != responseHost
  }

  private static func isHTMLContentType(response: HTTPURLResponse) -> Bool {
    guard let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
    else { return false }
    return contentType.contains("text/html")
  }
}
