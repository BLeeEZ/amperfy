//
//  AuthentificationHandshake.swift
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

// MARK: - LibraryChangeDates

public struct LibraryChangeDates: Comparable, Sendable {
  var dateOfLastUpdate = Date()
  var dateOfLastAdd = Date()
  var dateOfLastClean = Date()

  public static func < (lhs: LibraryChangeDates, rhs: LibraryChangeDates) -> Bool {
    switch lhs.dateOfLastAdd.compare(rhs.dateOfLastAdd) {
    case .orderedAscending: return true
    case .orderedDescending: return false
    case .orderedSame: return true
    }
  }

  public static func == (lhs: LibraryChangeDates, rhs: LibraryChangeDates) -> Bool {
    (lhs.dateOfLastUpdate == rhs.dateOfLastUpdate) && (lhs.dateOfLastAdd == rhs.dateOfLastAdd) &&
      (lhs.dateOfLastClean == rhs.dateOfLastClean)
  }
}

// MARK: - AuthentificationHandshake

struct AuthentificationHandshake: Sendable {
  var token: String = ""
  var sessionExpire = Date()
  var reauthenicateTime = Date()
  var libraryChangeDates = LibraryChangeDates()
  var songCount: Int = 0
  var artistCount: Int = 0
  var albumCount: Int = 0
  var genreCount: Int = 0
  var playlistCount: Int = 0
  var podcastCount: Int = 0
  var videoCount: Int = 0
}
