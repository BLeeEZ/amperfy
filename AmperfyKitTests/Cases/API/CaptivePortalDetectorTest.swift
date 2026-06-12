//
//  CaptivePortalDetectorTest.swift
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

class CaptivePortalDetectorTest: XCTestCase {
  let serverURL = URL(string: "https://music.example.com/api/ping")!

  override func setUp() {}

  override func tearDown() {}

  // MARK: - isCaptivePortalResponse

  func testNilResponse() {
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: nil, data: nil
    )
    XCTAssertFalse(result)
  }

  func testNormalJsonResponse() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 200,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"]
    )
    let data = "{\"status\":\"ok\"}".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertFalse(result)
  }

  func testNormalXmlResponse() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 200,
      httpVersion: nil, headerFields: ["Content-Type": "application/xml"]
    )
    let data = "<response status=\"ok\"/>".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertFalse(result)
  }

  func testHtmlContentTypeDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 200,
      httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"]
    )
    let data = "<html><body>Login</body></html>".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertTrue(result)
  }

  func testHtmlContentTypeUppercaseDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 200,
      httpVersion: nil, headerFields: ["Content-Type": "TEXT/HTML"]
    )
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: nil
    )
    XCTAssertTrue(result)
  }

  func testDomainRedirectDetected() {
    let redirectURL = URL(string: "https://auth.cloudflare.com/login")!
    let response = HTTPURLResponse(
      url: redirectURL, statusCode: 302,
      httpVersion: nil, headerFields: nil
    )
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: nil
    )
    XCTAssertTrue(result)
  }

  func test403WithHtmlBodyDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 403,
      httpVersion: nil, headerFields: ["Content-Type": "application/octet-stream"]
    )
    let data = "<!DOCTYPE html><html><body>Access Denied</body></html>".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertTrue(result)
  }

  func test403WithNonHtmlBodyNotDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 403,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"]
    )
    let data = "{\"error\":\"forbidden\"}".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertFalse(result)
  }

  func test403WithNilDataNotDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 403,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"]
    )
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: nil
    )
    XCTAssertFalse(result)
  }

  func testNon403ErrorWithHtmlBodyNotDetected() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 500,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"]
    )
    let data = "<html><body>Server Error</body></html>".data(using: .utf8)
    let result = CaptivePortalDetector.isCaptivePortalResponse(
      requestURL: serverURL, response: response, data: data
    )
    XCTAssertFalse(result)
  }

  // MARK: - isHTMLContent

  func testIsHTMLContentDoctype() {
    let data = "<!DOCTYPE html><html><body>test</body></html>".data(using: .utf8)!
    XCTAssertTrue(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentDoctypeUppercase() {
    let data = "<!DOCTYPE HTML><HTML><BODY>test</BODY></HTML>".data(using: .utf8)!
    XCTAssertTrue(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentHtmlTag() {
    let data = "<html lang=\"en\"><head></head><body>test</body></html>".data(using: .utf8)!
    XCTAssertTrue(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentWithLeadingWhitespace() {
    let data = "   \n  <!doctype html><html><body>test</body></html>".data(using: .utf8)!
    XCTAssertTrue(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentXml() {
    let data = "<?xml version=\"1.0\"?><subsonic-response status=\"ok\"/>".data(using: .utf8)!
    XCTAssertFalse(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentJson() {
    let data = "{\"status\":\"ok\",\"version\":\"1.16.1\"}".data(using: .utf8)!
    XCTAssertFalse(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentEmptyData() {
    let data = Data()
    XCTAssertFalse(CaptivePortalDetector.isHTMLContent(data: data))
  }

  func testIsHTMLContentOnlyChecksPrefix() {
    var content = String(repeating: "x", count: 600)
    content += "<html>"
    let data = content.data(using: .utf8)!
    XCTAssertFalse(CaptivePortalDetector.isHTMLContent(data: data))
  }

  // MARK: - isDomainRedirect

  func testDomainRedirectSameHost() {
    let response = HTTPURLResponse(
      url: serverURL, statusCode: 200, httpVersion: nil, headerFields: nil
    )
    XCTAssertFalse(
      CaptivePortalDetector.isDomainRedirect(requestURL: serverURL, response: response)
    )
  }

  func testDomainRedirectDifferentHost() {
    let redirectURL = URL(string: "https://idp.example.com/authorize")!
    let response = HTTPURLResponse(
      url: redirectURL, statusCode: 302, httpVersion: nil, headerFields: nil
    )
    XCTAssertTrue(
      CaptivePortalDetector.isDomainRedirect(requestURL: serverURL, response: response)
    )
  }

  func testDomainRedirectNilResponse() {
    XCTAssertFalse(
      CaptivePortalDetector.isDomainRedirect(requestURL: serverURL, response: nil)
    )
  }

  func testDomainRedirectCaseInsensitive() {
    let requestURL = URL(string: "https://Music.Example.COM/api")!
    let responseURL = URL(string: "https://music.example.com/api")!
    let response = HTTPURLResponse(
      url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil
    )
    XCTAssertFalse(
      CaptivePortalDetector.isDomainRedirect(requestURL: requestURL, response: response)
    )
  }

  func testDomainRedirectDifferentPath() {
    let responseURL = URL(string: "https://music.example.com/different/path")!
    let response = HTTPURLResponse(
      url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil
    )
    XCTAssertFalse(
      CaptivePortalDetector.isDomainRedirect(requestURL: serverURL, response: response)
    )
  }
}
