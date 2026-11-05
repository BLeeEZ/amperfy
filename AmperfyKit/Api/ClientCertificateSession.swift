//
//  ClientCertificateSession.swift
//  AmperfyKit
//
//  Created by Jerzy Królak on 08.05.26.
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
import os.log

// MARK: - ClientCertificateSession

public final class ClientCertificateSession: NSObject, URLSessionDelegate, @unchecked Sendable {
  public static let shared = ClientCertificateSession()

  private let lock = NSLock()
  private var activeAuthTask: Task<(), Error>?

  private override init() {
    super.init()
  }

  public func reauthenticateIfNeeded(accountTag: String, serverURL: URL) async throws {
    let existingTask: Task<(), Error>? = lock.withLock { activeAuthTask }
    if let existingTask {
      try await existingTask.value
      return
    }

    guard let credential = ClientCertificateManager.shared.getCredential(tag: accountTag) else {
      return
    }

    let task = Task {
      try await self.performHandshake(serverURL: serverURL, credential: credential)
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

  public func performHandshake(serverURL: URL, credential: URLCredential) async throws {
    let handler = ClientCertificateURLSessionDelegate(credential: credential)
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config, delegate: handler, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }

    var request = URLRequest(url: serverURL)
    request.httpMethod = "GET"

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ClientCertificateSessionError.invalidResponse
    }

    let statusCode = httpResponse.statusCode
    guard (200 ... 499).contains(statusCode) else {
      throw ClientCertificateSessionError.serverError(statusCode: statusCode)
    }

    os_log(
      .default,
      "mTLS handshake completed (status %d), cookies stored",
      statusCode
    )
  }
}

// MARK: - ClientCertificateURLSessionDelegate

final class ClientCertificateURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
  private let credential: URLCredential

  init(credential: URLCredential) {
    self.credential = credential
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()
  ) {
    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodClientCertificate:
      completionHandler(.useCredential, credential)
    case NSURLAuthenticationMethodServerTrust:
      if let trust = challenge.protectionSpace.serverTrust {
        completionHandler(.useCredential, URLCredential(trust: trust))
      } else {
        completionHandler(.performDefaultHandling, nil)
      }
    default:
      completionHandler(.performDefaultHandling, nil)
    }
  }
}

// MARK: - ClientCertificateSessionError

public enum ClientCertificateSessionError: LocalizedError {
  case invalidResponse
  case serverError(statusCode: Int)

  public var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Invalid response from server during certificate authentication."
    case let .serverError(statusCode):
      return "Server returned error \(statusCode) during certificate authentication."
    }
  }
}
