//
//  RadioPlaylistResolver.swift
//  AmperfyKit
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

import Foundation

// MARK: - RadioPlaylistResolver

/// Radio stations are often set up with a link to a playlist file (`.m3u`, `.pls`) that only
/// contains the actual stream URL. The audio player can't play the playlist itself, so the
/// stream URL is read from it first.
enum RadioPlaylistResolver {
  enum Format {
    case m3u
    case pls
  }

  /// Playlists are a few lines, anything larger is not a playlist
  static let maxPlaylistSize = 64 * 1024
  static let requestTimeout: TimeInterval = 10
  /// A playlist may point to another playlist
  static let maxDepth = 3

  /// The playlist can't be read or names no stream, retrying won't help
  struct InvalidPlaylistError: LocalizedError {
    let url: URL
    var errorDescription: String? {
      "The radio playlist \(url.absoluteString) contains no stream URL."
    }
  }

  /// Returns the stream URL of a playlist link, other URLs unchanged
  static func resolve(
    url: URL,
    session: URLSession = .shared,
    depth: Int = 0
  ) async throws
    -> URL {
    guard format(ofURL: url) != nil else { return url }
    guard depth < maxDepth else { throw InvalidPlaylistError(url: url) }
    var request = URLRequest(url: url)
    request.timeoutInterval = requestTimeout
    // the request timeout only limits idle time, a slowly trickling body is limited by this
    let deadline = Date().addingTimeInterval(requestTimeout)
    // streamed, a live stream behind a playlist extension would never finish downloading
    let (bytes, response) = try await session.bytes(for: request)
    defer { bytes.task.cancel() }
    if let httpResponse = response as? HTTPURLResponse,
       !(200 ..< 300).contains(httpResponse.statusCode) {
      // a server error or rate limit may be temporary, it is reported as a player error and
      // playing the radio again may work, unlike a broken playlist
      if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
        throw URLError(.badServerResponse)
      }
      throw InvalidPlaylistError(url: url)
    }
    // the server may answer with the stream itself despite the playlist extension, often
    // labeled as audio, octet-stream or not at all, so the content decides
    let isPlaylistMimeType = response.mimeType.map {
      let mimeType = $0.lowercased()
      return format(ofMimeType: mimeType) != nil || mimeType.hasPrefix("text/")
    } ?? false
    var data = Data()
    for try await byte in bytes {
      data.append(byte)
      if !isPlaylistMimeType, data.count == sniffLength, !looksLikePlaylist(data) {
        guard !looksLikeMarkup(data) else { throw InvalidPlaylistError(url: url) }
        return response.url ?? url
      }
      guard data.count <= maxPlaylistSize else { throw InvalidPlaylistError(url: url) }
      guard Date() < deadline else { throw URLError(.timedOut) }
    }
    // an error or login page instead of the playlist, its lines would be read as relative URLs
    guard !looksLikeMarkup(data) else { throw InvalidPlaylistError(url: url) }
    if !isPlaylistMimeType, !looksLikePlaylist(data) {
      return response.url ?? url
    }
    guard let content = String(data: data, encoding: .utf8) ??
      String(data: data, encoding: .isoLatin1),
      let streamUrl = streamURL(
        in: content,
        format: format(ofContent: content),
        baseURL: response.url ?? url
      )
    else {
      throw InvalidPlaylistError(url: url)
    }
    return try await resolve(url: streamUrl, session: session, depth: depth + 1)
  }

  /// The content decides, servers also deliver M3U for a .pls link and the other way round
  static func format(ofContent content: String) -> Format {
    let lines = content.components(separatedBy: .newlines)
      .map {
        $0.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}").union(.whitespaces))
          .lowercased()
      }
      .filter { !$0.isEmpty }
    // only the header counts, an M3U title may contain "[playlist]" too
    if lines.first == "[playlist]" { return .pls }
    return lines.contains(where: isPLSEntry) ? .pls : .m3u
  }

  /// `File1=…`, an M3U entry is a URL or a comment and never looks like this
  static func isPLSEntry(_ lowercasedLine: String) -> Bool {
    guard lowercasedLine.hasPrefix("file"),
          let separator = lowercasedLine.firstIndex(of: "=")
    else { return false }
    let number =
      lowercasedLine[lowercasedLine.index(lowercasedLine.startIndex, offsetBy: 4) ..< separator]
    return !number.isEmpty && number.allSatisfy { $0.isASCII && $0.isNumber }
  }

  static let sniffLength = 16

  /// Playlists start with a header, a comment or a URL, audio data doesn't
  static func looksLikePlaylist(_ data: Data) -> Bool {
    let head = sniffedHead(of: data)
    return head.hasPrefix("#") || head.hasPrefix("[playlist]") || head.hasPrefix("http")
  }

  /// HTML or XML, e.g. an error page served instead of the playlist
  static func looksLikeMarkup(_ data: Data) -> Bool {
    sniffedHead(of: data).hasPrefix("<")
  }

  private static func sniffedHead(of data: Data) -> String {
    String(decoding: data.prefix(sniffLength), as: UTF8.self)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}").union(.whitespacesAndNewlines))
      .lowercased()
  }

  static func format(ofURL url: URL) -> Format? {
    switch url.pathExtension.lowercased() {
    case "m3u": return .m3u
    case "pls": return .pls
    default: return nil
    }
  }

  static func format(ofMimeType mimeType: String) -> Format? {
    switch mimeType {
    case "audio/mpegurl", "audio/x-mpegurl": return .m3u
    case "audio/scpls", "audio/x-scpls": return .pls
    default: return nil
    }
  }

  /// The first stream URL in the playlist, relative entries are resolved against `baseURL`
  static func streamURL(in content: String, format: Format, baseURL: URL) -> URL? {
    let lines = content.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      // a byte order mark would hide the first entry
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}")) }
    let entries: [String]
    switch format {
    case .m3u:
      entries = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") }
    case .pls:
      // File1=…, File2=…; take the lowest number
      entries = lines.compactMap { line -> (Int, String)? in
        guard isPLSEntry(line.lowercased()), let separator = line.firstIndex(of: "=")
        else { return nil }
        let number = Int(line[line.index(line.startIndex, offsetBy: 4) ..< separator]) ?? .max
        let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : (number, value)
      }
      .sorted { $0.0 < $1.0 }
      .map(\.1)
    }
    for entry in entries {
      guard let url = URL(string: entry, relativeTo: baseURL)?.absoluteURL,
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
      else { continue }
      return url
    }
    return nil
  }
}
