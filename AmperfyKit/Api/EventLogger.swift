//
//  EventLogger.swift
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
import os.log
import UIKit

// MARK: - AmperfyLogStatusCode

public enum AmperfyLogStatusCode: Int {
  case downloadError = 1
  case playerError = 2
  case emailError = 3
  case internalError = 4
  case connectionError = 5
  case commonError = 6
  case info
}

// MARK: - AlertDisplayable

@MainActor
public protocol AlertDisplayable {
  func display(
    title: String,
    subtitle: String,
    style: LogEntryType,
    notificationBanner popupVC: UIViewController
  )
  func display(popup popupVC: UIViewController)
  func createPopupVC(
    topic: String,
    shortMessage: String,
    detailMessage: String,
    logType: LogEntryType
  ) -> UIViewController
}

// MARK: - EventLogger

@MainActor
public class EventLogger {
  public var supressAlerts = false

  private let log = OSLog(subsystem: "Amperfy", category: "EventLogger")
  public var alertDisplayer: AlertDisplayable?
  private let storage: PersistentStorage

  init(storage: PersistentStorage) {
    self.storage = storage
  }

  public func debug(topic: String, message: String) {
    report(
      topic: topic,
      statusCode: .info,
      shortMessage: message,
      detailMessage: message,
      logType: .debug,
      displayPopup: false
    )
  }

  public func info(topic: String, message: String, displayPopup: Bool = true) {
    report(
      topic: topic,
      statusCode: .info,
      shortMessage: message,
      detailMessage: message,
      logType: .info,
      displayPopup: displayPopup
    )
  }

  public func info(
    topic: String,
    statusCode: AmperfyLogStatusCode,
    message: String,
    displayPopup: Bool
  ) {
    report(
      topic: topic,
      statusCode: statusCode,
      shortMessage: message,
      detailMessage: message,
      logType: .info,
      displayPopup: displayPopup
    )
  }

  public func error(
    topic: String,
    statusCode: AmperfyLogStatusCode,
    message: String,
    displayPopup: Bool
  ) {
    report(
      topic: topic,
      statusCode: statusCode,
      shortMessage: message,
      detailMessage: message,
      logType: .error,
      displayPopup: displayPopup
    )
  }

  public func error(
    topic: String,
    statusCode: AmperfyLogStatusCode,
    shortMessage: String,
    detailMessage: String,
    displayPopup: Bool
  ) {
    report(
      topic: topic,
      statusCode: statusCode,
      shortMessage: shortMessage,
      detailMessage: detailMessage,
      logType: .error,
      displayPopup: displayPopup
    )
  }

  private func report(
    topic: String,
    statusCode: AmperfyLogStatusCode,
    shortMessage: String,
    detailMessage: String,
    logType: LogEntryType,
    displayPopup: Bool
  ) {
    saveAndDisplay(
      topic: topic,
      logType: logType,
      errorType: statusCode,
      statusCode: statusCode.rawValue,
      logMessage: topic + ": " + shortMessage,
      displayPopup: displayPopup,
      popupMessage: shortMessage,
      detailMessage: detailMessage
    )
  }

  public func report(topic: String, error: Error, displayPopup: Bool = true) {
    if let apiError = error as? ResponseError {
      return report(topic: topic, error: apiError, displayPopup: displayPopup)
    }
    saveAndDisplay(
      topic: topic,
      logType: .error,
      errorType: .commonError,
      statusCode: 0,
      logMessage: topic + ": " + error.localizedDescription,
      displayPopup: displayPopup,
      popupMessage: error.localizedDescription,
      detailMessage: error.localizedDescription
    )
  }

  public func report(topic: String, error: ResponseError, displayPopup: Bool) {
    var alertMessage = ""
    if error.statusCode > 0 {
      alertMessage += "Status code: \(error.statusCode)\n"
    }
    alertMessage += "\(error.message)"
    var detailMessage = "\(alertMessage)"
    if let cleansedURL = error.cleansedURL {
      detailMessage += "\n\nURL:\n\(cleansedURL.description)"
    }

    let isInfoError = error.type == .resource
    detailMessage += "\n\nError Content:\n" + error.asInfo(topic: topic).asJSONString()

    saveAndDisplay(
      topic: topic,
      logType: isInfoError ? .info : .apiError,
      errorType: isInfoError ? .info : .connectionError,
      statusCode: error.statusCode,
      logMessage: error.message,
      displayPopup: displayPopup,
      popupMessage: alertMessage,
      detailMessage: detailMessage
    )
  }

  private func saveAndDisplay(
    topic: String,
    logType: LogEntryType,
    errorType: AmperfyLogStatusCode,
    statusCode: Int,
    logMessage: String,
    displayPopup: Bool,
    popupMessage: String,
    detailMessage: String
  ) {
    os_log("%s", log: self.log, type: .error, logMessage)
    Task { @MainActor in
      do {
        try await storage.async.perform { asynCompanion in
          let logEntry = asynCompanion.library.createLogEntry()
          logEntry.type = logType
          logEntry.statusCode = statusCode
          logEntry.message = logMessage
          asynCompanion.saveContext()
        }
        if displayPopup {
          self.displayAlert(
            topic: topic,
            shortMessage: popupMessage,
            detailMessage: detailMessage,
            logType: logType
          )
        }
      } catch {
        // do nothing
      }
    }
  }

  private func displayAlert(
    topic: String,
    shortMessage: String,
    detailMessage: String,
    logType: LogEntryType
  ) {
    guard let displayer = alertDisplayer else { return }
    Task { @MainActor in
      guard !self.supressAlerts else { return }
      let popupVC = displayer.createPopupVC(
        topic: topic,
        shortMessage: shortMessage,
        detailMessage: detailMessage,
        logType: logType
      )
      displayer.display(
        title: topic,
        subtitle: shortMessage,
        style: logType,
        notificationBanner: popupVC
      )
    }
  }
}
