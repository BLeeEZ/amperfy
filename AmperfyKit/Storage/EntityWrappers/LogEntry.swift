//
//  LogEntry.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.05.21.
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
import CoreData

public enum LogEntryType: Int16, Sendable {
    case apiError = 0
    case error = 1
    case info = 2
    case debug = 3
    
    public var description : String {
        switch self {
        case .apiError: return "API Error"
        case .error: return "Error"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
}

public class LogEntry: NSObject {
    
    public let managedObject: LogEntryMO

    public init(managedObject: LogEntryMO) {
        self.managedObject = managedObject
    }
    
    public var creationDate: Date {
        get { return managedObject.creationDate }
        set { managedObject.creationDate = newValue }
    }
    
    public var message: String {
        get { return managedObject.message }
        set { managedObject.message = newValue }
    }
    
    public var statusCode: Int {
        get { return Int(managedObject.statusCode) }
        set { managedObject.statusCode = Int32(newValue) }
    }
    
    public var type: LogEntryType {
        get { return LogEntryType(rawValue: managedObject.type) ?? .error }
        set { managedObject.type = newValue.rawValue }
    }

}

extension LogEntry: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case creationDate, message, statusCode, type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(message, forKey: .message)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(type.description, forKey: .type)
    }

}
