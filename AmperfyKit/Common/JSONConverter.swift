//
//  JSONConverter.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.05.21.
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

// MARK: - JSONConverter

public enum JSONConverter {
  public static func decode<T: Decodable>(_ data: Data) throws -> [T]? {
    do {
      let decoded = try JSONDecoder().decode([T].self, from: data)
      return decoded
    } catch {
      throw error
    }
  }

  public static func encode<T: Encodable>(_ value: T) throws -> Data? {
    do {
      let data = try JSONEncoder().encode(value)
      return data
    } catch {
      throw error
    }
  }
}

extension Encodable {
  public func asJSONData() -> Data? {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    return try? encoder.encode(self)
  }

  public func asJSONString() -> String {
    guard let jsonData = asJSONData() else { return "<no serialized description>" }
    return String(decoding: jsonData, as: UTF8.self)
  }
}
