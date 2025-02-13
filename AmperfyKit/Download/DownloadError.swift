//
//  DownloadError.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
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

public enum DownloadError: Error {
  case urlInvalid
  case noConnectivity
  case alreadyDownloaded
  case fetchFailed
  case emptyFile
  case apiErrorResponse
  case canceled
  case fileManagerError

  public var description: String {
    switch self {
    case .urlInvalid: return "Invalid URL"
    case .noConnectivity: return "No Connectivity"
    case .alreadyDownloaded: return "Already Downloaded"
    case .fetchFailed: return "Fetch Failed"
    case .emptyFile: return "File is empty"
    case .apiErrorResponse: return "API Error"
    case .canceled: return "Cancled"
    case .fileManagerError: return "File Manager Error"
    }
  }

  var rawValue: Int {
    switch self {
    case .urlInvalid: return 1
    case .noConnectivity: return 2
    case .alreadyDownloaded: return 3
    case .fetchFailed: return 4
    case .emptyFile: return 5
    case .apiErrorResponse: return 6
    case .canceled: return 7
    case .fileManagerError: return 8
    }
  }

  public static func create(rawValue: Int) -> DownloadError? {
    switch rawValue {
    case 1: return .urlInvalid
    case 2: return .noConnectivity
    case 3: return .alreadyDownloaded
    case 4: return .fetchFailed
    case 5: return .emptyFile
    case 6: return .apiErrorResponse
    case 7: return .canceled
    case 8: return .fileManagerError
    default:
      return nil
    }
  }
}
