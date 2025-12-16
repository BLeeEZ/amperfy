//
//  Radio.swift
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
import UIKit

public class Radio: AbstractPlayable, Identifyable {
  public let managedObject: RadioMO

  public init(managedObject: RadioMO) {
    self.managedObject = managedObject
    super.init(managedObject: managedObject)
  }

  public var siteURL: URL? {
    get {
      guard let siteUrlString = managedObject.siteUrl else { return nil }
      return URL(string: siteUrlString)
    }
    set {
      managedObject.siteUrl = newValue?.absoluteString
    }
  }

  override public var creatorName: String {
    ""
  }

  override public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if details.type == .long {
      if let siteUrl = siteURL {
        infoContent.append("Site \(siteUrl)")
      }
      if let urlString = url {
        infoContent.append("Steam URL \(urlString)")
      }
    }
    return infoContent
  }

  public var identifier: String {
    title
  }

  override public func isAvailableToUser() -> Bool {
    // See also RadioMO.excludeServerDeleteRadiosFetchPredicate()
    remoteStatus == .available
  }
}
