//
//  UnitTestHelper.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.06.21.
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

import AmperfyKit
import Foundation
import XCTest

// MARK: - MOCK_PerformanceMonitor

final public class MOCK_PerformanceMonitor: ThreadPerformanceMonitor {
  nonisolated public var shouldSlowDownExecution: Bool { false }
  nonisolated public var isInForeground: Bool {
    get { true }
    set {}
  }
}

// MARK: - Helper

class Helper {
  static let testURL = URL(string: "https://github.com/BLeeEZ/amperfy")!
}

extension XCTestCase {
  func getTestFileData(name: String, withExtension: String = "xml") -> Data {
    let bundle = Bundle(for: type(of: self))
    let fileUrl = bundle.url(forResource: name, withExtension: withExtension)
    let data = try! Data(contentsOf: fileUrl!)
    return data
  }
}
