//
//  Created by Dimitrios Chatzieleftheriou on 28/07/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation
import OSLog

private let loggingSubsystem = "audio.streaming.log"

extension Logger {
  public static let audioRendering = Logger(
    subsystem: loggingSubsystem,
    category: "audio.rendering"
  )
  public static let networking = Logger(subsystem: loggingSubsystem, category: "audio.networking")
  public static let generic = Logger(
    subsystem: loggingSubsystem,
    category: "audio.streaming.generic"
  )

  /// Defines is the the logger displays any logs
  static var isEnabled = true

  enum Category: CaseIterable {
    case audioRendering
    case networking
    case generic

    func toOSLog() -> Logger {
      switch self {
      case .audioRendering: return Logger.audioRendering
      case .networking: return Logger.networking
      case .generic: return Logger.generic
      }
    }
  }

  static func error(_ message: String, category: Category, args: CVarArg...) {
    process(message, category: category, type: .error, args: args)
  }

  static func error(_ message: String, category: Category) {
    error(message, category: category, args: [])
  }

  static func debug(_ message: String, category: Category, args: CVarArg...) {
    process(message, category: category, type: .debug, args: args)
  }

  static func debug(_ message: String, category: Category) {
    debug(message, category: category, args: [])
  }

  private static func process(
    _ message: String,
    category: Category,
    type: OSLogType,
    args: CVarArg...
  ) {
    guard isEnabled else { return }
    switch type {
    case .debug:
      category.toOSLog().debug("\(message)")
    case .error:
      category.toOSLog().error("\(message)")
    default:
      category.toOSLog().info("\(message)")
    }
  }
}
