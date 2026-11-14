//
//  RadioPlaylistResolverTest.swift
//  AmperfyKitTests
//
//  Created by Chrizz Gelbach on 13.11.26.
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

// MARK: - MOCK_RadioPlaylistURLProtocol

/// Answers requests from routes registered per host, each test uses its own host so tests
/// don't share routes. Unknown paths get a 404.
final class MOCK_RadioPlaylistURLProtocol: URLProtocol {
  struct Route {
    let statusCode: Int
    let contentType: String
    let body: Data
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var routes: [String: Route] = [:]
  nonisolated(unsafe) private static var requestCounts: [String: Int] = [:]

  static func register(url: URL, route: Route) {
    lock.withLock { routes[url.absoluteString] = route }
  }

  static func requestCount(host: String) -> Int {
    lock.withLock { requestCounts[host] ?? 0 }
  }

  static func reset(host: String) {
    lock.withLock {
      routes = routes.filter { URL(string: $0.key)?.host != host }
      requestCounts[host] = nil
    }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url, let host = url.host else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let route = Self.lock.withLock {
      Self.requestCounts[host, default: 0] += 1
      return Self.routes[url.absoluteString]
    } ?? Route(statusCode: 404, contentType: "text/html", body: Data("Not Found".utf8))
    guard let response = HTTPURLResponse(
      url: url,
      statusCode: route.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": route.contentType]
    ) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: route.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

// MARK: - RadioPlaylistResolverTest

final class RadioPlaylistResolverTest: XCTestCase {
  let base = URL(string: "https://radio.example/stream/station.m3u")!

  // MARK: Parsing

  func testM3U_ExtendedWithComments_ReturnsFirstURL() {
    // the playlist from issue #777
    let content = "#EXTM3U\n#EXTINF:-1,Le Son Parisien\nhttp://stream.lesonparisien.com/hi.mp3\n"
    XCTAssertEqual(
      RadioPlaylistResolver.streamURL(in: content, format: .m3u, baseURL: base)?.absoluteString,
      "http://stream.lesonparisien.com/hi.mp3"
    )
  }

  func testM3U_WindowsLineEndingsAndBOM() {
    let content = "\u{FEFF}https://a.example/live\r\nhttps://b.example/live\r\n"
    XCTAssertEqual(
      RadioPlaylistResolver.streamURL(in: content, format: .m3u, baseURL: base)?.absoluteString,
      "https://a.example/live"
    )
  }

  func testM3U_RelativeEntry_ResolvedAgainstPlaylist() {
    XCTAssertEqual(
      RadioPlaylistResolver.streamURL(in: "live.mp3\n", format: .m3u, baseURL: base)?
        .absoluteString,
      "https://radio.example/stream/live.mp3"
    )
  }

  func testM3U_OnlyComments_ReturnsNil() {
    XCTAssertNil(RadioPlaylistResolver.streamURL(in: "#EXTM3U\n\n", format: .m3u, baseURL: base))
  }

  func testM3U_SkipsNonHTTPEntries() {
    let content = "file:///etc/hosts\nmailto:x@example.com\nhttps://ok.example/live\n"
    XCTAssertEqual(
      RadioPlaylistResolver.streamURL(in: content, format: .m3u, baseURL: base)?.absoluteString,
      "https://ok.example/live"
    )
  }

  func testPLS_ReturnsLowestFileNumber() {
    let content = """
    [playlist]
    NumberOfEntries=2
    File2=https://backup.example/live
    Title2=Backup
    File1=https://main.example/live
    Title1=Main
    Version=2
    """
    XCTAssertEqual(
      RadioPlaylistResolver.streamURL(in: content, format: .pls, baseURL: base)?.absoluteString,
      "https://main.example/live"
    )
  }

  func testPLS_NoFileEntries_ReturnsNil() {
    XCTAssertNil(RadioPlaylistResolver.streamURL(
      in: "[playlist]\nNumberOfEntries=0\n",
      format: .pls,
      baseURL: base
    ))
  }

  func testFormatOfURL() {
    XCTAssertEqual(RadioPlaylistResolver.format(ofURL: URL(string: "http://a/b.M3U")!), .m3u)
    XCTAssertEqual(RadioPlaylistResolver.format(ofURL: URL(string: "http://a/b.pls?x=1")!), .pls)
    // HLS is a different format
    XCTAssertNil(RadioPlaylistResolver.format(ofURL: URL(string: "http://a/b.m3u8")!))
    XCTAssertNil(RadioPlaylistResolver.format(ofURL: URL(string: "http://a/hi.mp3")!))
  }

  func testLooksLikePlaylist() {
    XCTAssertTrue(RadioPlaylistResolver.looksLikePlaylist(Data("#EXTM3U\n".utf8)))
    XCTAssertTrue(RadioPlaylistResolver.looksLikePlaylist(Data("[playlist]\n".utf8)))
    XCTAssertTrue(RadioPlaylistResolver.looksLikePlaylist(Data("\u{FEFF}http://a/b".utf8)))
    XCTAssertFalse(RadioPlaylistResolver.looksLikePlaylist(Data([0xFF, 0xFB, 0x90, 0x64, 0x00])))
    XCTAssertFalse(RadioPlaylistResolver.looksLikePlaylist(Data("ID3\u{04}".utf8)))
  }

  // MARK: Network

  var host = ""
  var session: URLSession!

  override func setUp() async throws {
    host = "\(UUID().uuidString.lowercased()).stub.amperfy.test"
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MOCK_RadioPlaylistURLProtocol.self]
    session = URLSession(configuration: configuration)
  }

  override func tearDown() async throws {
    session.invalidateAndCancel()
    session = nil
    MOCK_RadioPlaylistURLProtocol.reset(host: host)
  }

  func url(path: String) -> URL {
    URL(string: "https://\(host)\(path)")!
  }

  func serve(path: String, data: Data, contentType: String, statusCode: Int = 200) {
    MOCK_RadioPlaylistURLProtocol.register(
      url: url(path: path),
      route: .init(statusCode: statusCode, contentType: contentType, body: data)
    )
  }

  var requestCount: Int {
    MOCK_RadioPlaylistURLProtocol.requestCount(host: host)
  }

  func resolve(_ url: URL) async throws -> URL {
    try await RadioPlaylistResolver.resolve(url: url, session: session)
  }

  func testResolve_PlainStreamURL_Unchanged() async throws {
    let url = url(path: "/live.mp3")
    let resolved = try await resolve(url)
    XCTAssertEqual(resolved, url)
    XCTAssertEqual(requestCount, 0, "no request for a stream URL")
  }

  func testResolve_M3U_ReturnsStreamURL() async throws {
    let stream = url(path: "/live.wav")
    serve(
      path: "/station.m3u",
      data: Data("#EXTM3U\n#EXTINF:-1,Station\n\(stream.absoluteString)\n".utf8),
      contentType: "audio/mpegurl"
    )
    let resolved = try await resolve(url(path: "/station.m3u"))
    XCTAssertEqual(resolved, stream)
  }

  func testResolve_PLSPointingToM3U_ResolvesBoth() async throws {
    serve(
      path: "/station.pls",
      data: Data("[playlist]\nFile1=/inner.m3u\n".utf8),
      contentType: "audio/x-scpls"
    )
    serve(path: "/inner.m3u", data: Data("/live.wav\n".utf8), contentType: "text/plain")
    let resolved = try await resolve(url(path: "/station.pls"))
    XCTAssertEqual(resolved, url(path: "/live.wav"))
  }

  func testResolve_PlaylistLabeledAsAudio_IsParsed() async throws {
    serve(
      path: "/station.m3u",
      data: Data("http://stream.example/hi.mp3\n".utf8),
      contentType: "audio/mpeg"
    )
    let resolved = try await resolve(url(path: "/station.m3u"))
    XCTAssertEqual(resolved.absoluteString, "http://stream.example/hi.mp3")
  }

  func testResolve_AudioBehindPlaylistExtension_ReturnsURL() async throws {
    serve(
      path: "/station.m3u",
      data: Data("RIFF".utf8) + Data(count: 4) + Data("WAVEfmt ".utf8) + Data(count: 1000),
      contentType: "audio/wav"
    )
    let url = url(path: "/station.m3u")
    let resolved = try await resolve(url)
    XCTAssertEqual(resolved, url)
  }

  func testResolve_ServerError_ThrowsRetryableError() async {
    serve(path: "/station.m3u", data: Data(), contentType: "text/html", statusCode: 503)
    do {
      _ = try await resolve(url(path: "/station.m3u"))
      XCTFail("expected an error")
    } catch {
      // a temporary server error goes through the player's error handling, not the invalid URL path
      XCTAssertFalse(error is RadioPlaylistResolver.InvalidPlaylistError)
    }
  }

  func testResolve_EmptyPlaylist_Throws() async {
    serve(path: "/station.m3u", data: Data("#EXTM3U\n".utf8), contentType: "audio/x-mpegurl")
    do {
      _ = try await resolve(url(path: "/station.m3u"))
      XCTFail("expected an error")
    } catch {}
  }

  func testResolve_EndlessPlaylistLoop_ThrowsAtMaxDepth() async {
    serve(
      path: "/station.m3u",
      data: Data("/station.m3u\n".utf8),
      contentType: "audio/x-mpegurl"
    )
    do {
      _ = try await resolve(url(path: "/station.m3u"))
      XCTFail("expected an error")
    } catch {
      XCTAssertTrue(error is RadioPlaylistResolver.InvalidPlaylistError)
    }
    XCTAssertEqual(requestCount, RadioPlaylistResolver.maxDepth)
  }

  func testResolve_StreamAsOctetStreamBehindPlaylistExtension_ReturnsURL() async throws {
    var mp3Frames = Data([0xFF, 0xFB, 0x90, 0x64])
    mp3Frames.append(Data(count: 200_000))
    serve(path: "/live.m3u", data: mp3Frames, contentType: "application/octet-stream")
    let url = url(path: "/live.m3u")
    let resolved = try await resolve(url)
    XCTAssertEqual(resolved, url)
  }

  func testResolve_PLSExtensionWithM3UContent_IsParsed() async throws {
    serve(
      path: "/station.pls",
      data: Data("#EXTM3U\nhttp://stream.example/live\n".utf8),
      contentType: "audio/x-scpls"
    )
    let resolved = try await resolve(url(path: "/station.pls"))
    XCTAssertEqual(resolved.absoluteString, "http://stream.example/live")
  }

  func testResolve_NotFound_ThrowsInvalidPlaylist() async {
    do {
      _ = try await resolve(url(path: "/missing.m3u"))
      XCTFail("expected an error")
    } catch {
      XCTAssertTrue(error is RadioPlaylistResolver.InvalidPlaylistError)
    }
  }

  func testFormatOfContent() {
    XCTAssertEqual(RadioPlaylistResolver.format(ofContent: "[playlist]\nFile1=http://a"), .pls)
    XCTAssertEqual(RadioPlaylistResolver.format(ofContent: "File1=http://a\n"), .pls)
    XCTAssertEqual(RadioPlaylistResolver.format(ofContent: "#EXTM3U\nhttp://a\n"), .m3u)
  }
}
