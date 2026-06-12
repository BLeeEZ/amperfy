//
//  CaptivePortalSessionTest.swift
//  AmperfyKitTests
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

@testable import AmperfyKit
import XCTest

// MARK: - MOCK_CaptivePortalAuthHandler

final class MOCK_CaptivePortalAuthHandler: CaptivePortalAuthHandler, @unchecked Sendable {
  var authCallCount = 0
  var lastServerURL: URL?
  var lastClearSession = false
  var shouldThrow: CaptivePortalError?

  @MainActor
  func performCaptivePortalAuth(serverURL: URL, clearSession: Bool) async throws {
    authCallCount += 1
    lastServerURL = serverURL
    lastClearSession = clearSession
    if let error = shouldThrow {
      throw error
    }
  }
}

// MARK: - CaptivePortalSessionTest

@MainActor
class CaptivePortalSessionTest: XCTestCase {
  var session: CaptivePortalSession!
  var mockHandler: MOCK_CaptivePortalAuthHandler!

  override func setUp() {
    session = CaptivePortalSession.shared
    session.resetForTesting()
    mockHandler = MOCK_CaptivePortalAuthHandler()
    session.authHandler = mockHandler
  }

  override func tearDown() {
    session.authHandler = nil
  }

  // MARK: - authenticate

  func testAuthenticateCallsHandler() async throws {
    let url = URL(string: "https://music.example.com")!
    try await session.authenticate(serverURL: url)
    XCTAssertEqual(mockHandler.authCallCount, 1)
    XCTAssertEqual(mockHandler.lastServerURL, url)
  }

  func testAuthenticateNoHandlerThrows() async {
    session.authHandler = nil
    let url = URL(string: "https://music.example.com")!
    do {
      try await session.authenticate(serverURL: url)
      XCTFail("Expected error")
    } catch let error as CaptivePortalError {
      XCTAssertEqual(error, .noAuthHandler)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testAuthenticateForwardsHandlerError() async {
    mockHandler.shouldThrow = .authenticationFailed
    let url = URL(string: "https://music.example.com")!
    do {
      try await session.authenticate(serverURL: url)
      XCTFail("Expected error")
    } catch let error as CaptivePortalError {
      XCTAssertEqual(error, .authenticationFailed)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - logout

  func testLogoutClearsCookies() {
    let cookie = HTTPCookie(properties: [
      .name: "CF_Authorization",
      .value: "test-token",
      .domain: "music.example.com",
      .path: "/",
    ])!
    HTTPCookieStorage.shared.setCookie(cookie)

    let beforeCount = HTTPCookieStorage.shared.cookies?.filter {
      $0.name == "CF_Authorization" && $0.domain == "music.example.com"
    }.count ?? 0
    XCTAssertEqual(beforeCount, 1)

    session.logout()

    let afterCount = HTTPCookieStorage.shared.cookies?.filter {
      $0.name == "CF_Authorization" && $0.domain == "music.example.com"
    }.count ?? 0
    XCTAssertEqual(afterCount, 0)
  }

  func testLogoutClearsAllCookies() {
    let serverCookie = HTTPCookie(properties: [
      .name: "CF_Authorization",
      .value: "test-token",
      .domain: "music.example.com",
      .path: "/",
    ])!
    let auth0Cookie = HTTPCookie(properties: [
      .name: "auth0_session",
      .value: "session-value",
      .domain: "login.auth0.com",
      .path: "/",
    ])!
    HTTPCookieStorage.shared.setCookie(serverCookie)
    HTTPCookieStorage.shared.setCookie(auth0Cookie)

    session.logout()

    let remaining = HTTPCookieStorage.shared.cookies?.filter {
      $0.name == "CF_Authorization" || $0.name == "auth0_session"
    } ?? []
    XCTAssertEqual(remaining.count, 0)
  }

  // MARK: - clearSession flag

  func testNoClearSessionByDefault() async throws {
    let url = URL(string: "https://music.example.com")!
    try await session.authenticate(serverURL: url)
    XCTAssertFalse(mockHandler.lastClearSession)
  }

  func testClearSessionAfterLogout() async throws {
    let url = URL(string: "https://music.example.com")!
    session.logout()
    try await session.authenticate(serverURL: url)
    XCTAssertTrue(mockHandler.lastClearSession)
  }

  func testClearSessionFlagConsumedAfterAuth() async throws {
    let url = URL(string: "https://music.example.com")!
    session.logout()
    try await session.authenticate(serverURL: url)
    XCTAssertTrue(mockHandler.lastClearSession)

    try await session.authenticate(serverURL: url)
    XCTAssertFalse(mockHandler.lastClearSession)
  }

  func testClearSessionFlagNotSetOnSessionExpiry() async throws {
    let url = URL(string: "https://music.example.com")!
    try await session.authenticate(serverURL: url)
    XCTAssertFalse(mockHandler.lastClearSession)

    try await session.authenticate(serverURL: url)
    XCTAssertFalse(mockHandler.lastClearSession)
  }

  // MARK: - CaptivePortalError

  func testErrorDescriptions() {
    XCTAssertNotNil(CaptivePortalError.captivePortalDetected.errorDescription)
    XCTAssertNotNil(CaptivePortalError.noAuthHandler.errorDescription)
    XCTAssertNotNil(CaptivePortalError.authenticationFailed.errorDescription)
    XCTAssertNotNil(CaptivePortalError.userCancelled.errorDescription)
  }

  func testErrorEquality() {
    XCTAssertEqual(CaptivePortalError.captivePortalDetected, .captivePortalDetected)
    XCTAssertNotEqual(CaptivePortalError.captivePortalDetected, .userCancelled)
  }
}
