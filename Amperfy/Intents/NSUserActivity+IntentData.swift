//
//  NSUserActivity+IntentData.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import AppIntents
import Foundation
import SwiftUI
import UIKit

// MARK: - NSUserActivity.ActivityKeys

extension NSUserActivity {
  public enum ActivityKeys: String {
    case searchTerm
    case searchCategory
    case id
    case libraryElementType
    case shuffleOption
    case repeatOption
    case offlineMode
    case onlyCached
    case rating
    case favorite
  }
}

extension AppIntent {
  @MainActor
  var appDelegate: AppDelegate {
    (UIApplication.shared.delegate as! AppDelegate)
  }
}

extension EntityQuery {
  @MainActor
  var appDelegate: AppDelegate {
    (UIApplication.shared.delegate as! AppDelegate)
  }
}

extension View {
  var intentResultViewHeaderImageFont: Font {
    .system(size: 30, weight: .bold)
  }
}
