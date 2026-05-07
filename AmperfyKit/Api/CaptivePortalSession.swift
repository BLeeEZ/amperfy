//
//  CaptivePortalSession.swift
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

// MARK: - CaptivePortalAuthHandler

public protocol CaptivePortalAuthHandler: AnyObject, Sendable {
  @MainActor
  func performCaptivePortalAuth(serverURL: URL, clearSession: Bool) async throws
}

// MARK: - CaptivePortalError

public enum CaptivePortalError: LocalizedError, Equatable {
  case captivePortalDetected
  case noAuthHandler
  case authenticationFailed
  case userCancelled

  public var errorDescription: String? {
    switch self {
    case .captivePortalDetected:
      return "Server is behind a network authentication portal."
    case .noAuthHandler:
      return "Captive portal auth handler not configured."
    case .authenticationFailed:
      return "Network authentication failed. Please try again."
    case .userCancelled:
      return "Authentication was cancelled."
    }
  }
}

// MARK: - CaptivePortalSession

public final class CaptivePortalSession: @unchecked Sendable {
  public static let shared = CaptivePortalSession()

  private let lock = NSLock()
  private var _authHandler: (any CaptivePortalAuthHandler)?
  private var _needsSessionClear = false
  private var activeAuthTask: Task<(), Error>?

  public var authHandler: (any CaptivePortalAuthHandler)? {
    get { lock.withLock { _authHandler } }
    set { lock.withLock { _authHandler = newValue } }
  }

  private init() {}

  @MainActor
  public func authenticate(serverURL: URL) async throws {
    let existingTask: Task<(), Error>? = lock.withLock { activeAuthTask }
    if let existingTask {
      try await existingTask.value
      return
    }

    let clearSession = lock.withLock {
      let val = _needsSessionClear
      _needsSessionClear = false
      return val
    }

    let task = Task { @MainActor in
      guard let handler = self.authHandler else {
        throw CaptivePortalError.noAuthHandler
      }
      try await handler.performCaptivePortalAuth(serverURL: serverURL, clearSession: clearSession)
    }
    lock.withLock { activeAuthTask = task }

    do {
      try await task.value
      lock.withLock { activeAuthTask = nil }
    } catch {
      lock.withLock { activeAuthTask = nil }
      throw error
    }
  }

  /// Call on explicit logout. Clears HTTPCookieStorage immediately and marks
  /// WKWebView data for clearing on the next auth attempt.
  public func logout() {
    HTTPCookieStorage.shared.cookies?.forEach { cookie in
      HTTPCookieStorage.shared.deleteCookie(cookie)
    }
    lock.withLock { _needsSessionClear = true }
  }

  #if DEBUG
    public func resetForTesting() {
      lock.withLock {
        _needsSessionClear = false
        activeAuthTask = nil
      }
    }
  #endif
}
