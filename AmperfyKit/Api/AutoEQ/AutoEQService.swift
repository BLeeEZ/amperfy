//
//  AutoEQService.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.01.26.
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

// MARK: - AutoEQHeadphone

/// Represents a headphone entry from the AutoEQ database
public struct AutoEQHeadphone: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let source: String  // e.g., "oratory1990", "crinacle", etc.
  public let category: Category
  public let path: String  // GitHub path to the headphone folder
  
  public enum Category: String, CaseIterable, Sendable {
    case overEar = "over-ear"
    case inEar = "in-ear"
    case earbud = "earbud"
    case unknown = "unknown"
    
    public var displayName: String {
      switch self {
      case .overEar: return "Over-Ear"
      case .inEar: return "In-Ear"
      case .earbud: return "Earbud"
      case .unknown: return "Other"
      }
    }
  }
  
  public init(name: String, source: String, category: Category, path: String) {
    self.id = path
    self.name = name
    self.source = source
    self.category = category
    self.path = path
  }
}

// MARK: - AutoEQPresetData

/// Parsed EQ preset data from AutoEQ
public struct AutoEQPresetData: Sendable {
  public let headphoneName: String
  public let preamp: Float
  public let gains: [Float]  // 10 bands: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
  
  /// Convert to EqualizerSetting for use in the app
  public var asEqualizerSetting: EqualizerSetting {
    EqualizerSetting(name: "AutoEQ: \(headphoneName)", gains: gains)
  }
}

// MARK: - AutoEQService

/// Service for fetching headphone EQ presets from the AutoEQ GitHub repository
/// Source: https://github.com/jaakkopasanen/AutoEq
@MainActor
public class AutoEQService: ObservableObject {
  
  // MARK: - Published Properties
  
  @Published public private(set) var isLoading = false
  @Published public private(set) var headphones: [AutoEQHeadphone] = []
  @Published public private(set) var searchResults: [AutoEQHeadphone] = []
  @Published public private(set) var error: Error?
  
  // MARK: - Private Properties
  
  private let baseURL = "https://api.github.com/repos/jaakkopasanen/AutoEq"
  private let rawBaseURL = "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master"
  
  // Trusted measurement sources (oratory1990 is considered the gold standard)
  private let trustedSources = ["oratory1990", "crinacle", "Rtings"]
  
  private var indexCache: [AutoEQHeadphone]?
  private var lastIndexFetch: Date?
  private let cacheExpiry: TimeInterval = 3600 * 24  // 24 hours
  
  private let session: URLSession
  
  // MARK: - Initialization
  
  public init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.requestCachePolicy = .returnCacheDataElseLoad
    self.session = URLSession(configuration: config)
  }
  
  // MARK: - Public Methods
  
  /// Search for headphones by name
  public func search(query: String) async {
    guard !query.isEmpty else {
      searchResults = []
      return
    }
    
    // Ensure we have the index loaded
    if headphones.isEmpty {
      await loadIndex()
    }
    
    let lowercasedQuery = query.lowercased()
    searchResults = headphones.filter { headphone in
      headphone.name.lowercased().contains(lowercasedQuery)
    }
    .sorted { lhs, rhs in
      // Prioritize exact prefix matches
      let lhsPrefix = lhs.name.lowercased().hasPrefix(lowercasedQuery)
      let rhsPrefix = rhs.name.lowercased().hasPrefix(lowercasedQuery)
      if lhsPrefix != rhsPrefix {
        return lhsPrefix
      }
      // Then sort by trusted source
      let lhsTrusted = trustedSources.contains(lhs.source)
      let rhsTrusted = trustedSources.contains(rhs.source)
      if lhsTrusted != rhsTrusted {
        return lhsTrusted
      }
      return lhs.name < rhs.name
    }
  }
  
  /// Load the headphone index from GitHub
  public func loadIndex() async {
    // Check cache
    if let cached = indexCache,
       let lastFetch = lastIndexFetch,
       Date().timeIntervalSince(lastFetch) < cacheExpiry {
      headphones = cached
      return
    }
    
    isLoading = true
    error = nil
    
    do {
      var allHeadphones: [AutoEQHeadphone] = []
      
      // Load from trusted sources
      for source in trustedSources {
        let sourceHeadphones = try await loadHeadphonesFromSource(source)
        allHeadphones.append(contentsOf: sourceHeadphones)
      }
      
      headphones = allHeadphones.sorted { $0.name < $1.name }
      indexCache = headphones
      lastIndexFetch = Date()
      
      os_log(.info, "AutoEQ: Loaded %d headphones from index", headphones.count)
    } catch {
      self.error = error
      os_log(.error, "AutoEQ: Failed to load index: %{public}@", error.localizedDescription)
    }
    
    isLoading = false
  }
  
  /// Fetch the EQ preset for a specific headphone
  public func fetchPreset(for headphone: AutoEQHeadphone) async throws -> AutoEQPresetData {
    // Construct the URL for the FixedBandEQ.txt file
    // The filename format is: "HeadphoneName FixedBandEQ.txt"
    let filename = "\(headphone.name) FixedBandEQ.txt"
    
    // Create a character set for URL encoding that excludes spaces
    // urlPathAllowed includes spaces, but we need them encoded for GitHub raw URLs
    var allowedCharacters = CharacterSet.urlPathAllowed
    allowedCharacters.remove(charactersIn: " ")
    
    let encodedPath = headphone.path.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? headphone.path
    let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? filename
    let fileURL = "\(rawBaseURL)/\(encodedPath)/\(encodedFilename)"
    
    guard let url = URL(string: fileURL) else {
      throw AutoEQError.invalidURL
    }
    
    os_log(.info, "AutoEQ: Fetching preset from %{public}@", fileURL)
    
    let (data, response) = try await session.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw AutoEQError.fetchFailed
    }
    
    guard let content = String(data: data, encoding: .utf8) else {
      throw AutoEQError.invalidData
    }
    
    return try parseFixedBandEQ(content: content, headphoneName: headphone.name)
  }
  
  // MARK: - Private Methods
  
  private func loadHeadphonesFromSource(_ source: String) async throws -> [AutoEQHeadphone] {
    var headphones: [AutoEQHeadphone] = []
    
    // Load each category
    for category in AutoEQHeadphone.Category.allCases where category != .unknown {
      let categoryHeadphones = try await loadHeadphonesFromCategory(source: source, category: category)
      headphones.append(contentsOf: categoryHeadphones)
    }
    
    return headphones
  }
  
  private func loadHeadphonesFromCategory(
    source: String,
    category: AutoEQHeadphone.Category
  ) async throws -> [AutoEQHeadphone] {
    let path = "results/\(source)/\(category.rawValue)"
    let urlString = "\(baseURL)/contents/\(path)"
    
    guard let url = URL(string: urlString) else {
      return []
    }
    
    do {
      let (data, response) = try await session.data(from: url)
      
      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        return []
      }
      
      let items = try JSONDecoder().decode([GitHubContentItem].self, from: data)
      
      return items.compactMap { item -> AutoEQHeadphone? in
        guard item.type == "dir" else { return nil }
        return AutoEQHeadphone(
          name: item.name,
          source: source,
          category: category,
          path: item.path
        )
      }
    } catch {
      os_log(.debug, "AutoEQ: No headphones found at %{public}@", path)
      return []
    }
  }
  
  private func parseFixedBandEQ(content: String, headphoneName: String) throws -> AutoEQPresetData {
    let lines = content.components(separatedBy: .newlines)
    
    var preamp: Float = 0
    var gains: [Float] = Array(repeating: 0, count: 10)
    
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      // Parse preamp line: "Preamp: -7.4 dB"
      if trimmed.hasPrefix("Preamp:") {
        if let value = extractDBValue(from: trimmed) {
          preamp = value
        }
      }
      // Parse filter lines: "Filter 1: ON PK Fc 31 Hz Gain 7.0 dB Q 1.41"
      else if trimmed.hasPrefix("Filter") {
        if let (filterIndex, gain) = parseFilterLine(trimmed) {
          let arrayIndex = filterIndex - 1
          if arrayIndex >= 0 && arrayIndex < 10 {
            gains[arrayIndex] = gain
          }
        }
      }
    }
    
    // Map AutoEQ frequencies (31, 62 Hz) to our frequencies (32, 64 Hz) - close enough
    return AutoEQPresetData(
      headphoneName: headphoneName,
      preamp: preamp,
      gains: gains
    )
  }
  
  private func extractDBValue(from string: String) -> Float? {
    // Extract number before "dB"
    let pattern = #"(-?\d+\.?\d*)\s*dB"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
          let range = Range(match.range(at: 1), in: string) else {
      return nil
    }
    return Float(string[range])
  }
  
  private func parseFilterLine(_ line: String) -> (index: Int, gain: Float)? {
    // Parse: "Filter 1: ON PK Fc 31 Hz Gain 7.0 dB Q 1.41"
    let filterPattern = #"Filter\s+(\d+):"#
    let gainPattern = #"Gain\s+(-?\d+\.?\d*)\s*dB"#
    
    guard let filterRegex = try? NSRegularExpression(pattern: filterPattern),
          let gainRegex = try? NSRegularExpression(pattern: gainPattern),
          let filterMatch = filterRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let gainMatch = gainRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let filterRange = Range(filterMatch.range(at: 1), in: line),
          let gainRange = Range(gainMatch.range(at: 1), in: line),
          let filterIndex = Int(line[filterRange]),
          let gain = Float(line[gainRange]) else {
      return nil
    }
    
    return (filterIndex, gain)
  }
}

// MARK: - GitHubContentItem

private struct GitHubContentItem: Decodable {
  let name: String
  let path: String
  let type: String  // "file" or "dir"
}

// MARK: - AutoEQError

public enum AutoEQError: LocalizedError {
  case invalidURL
  case fetchFailed
  case invalidData
  case parseError
  
  public var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid URL for AutoEQ preset"
    case .fetchFailed:
      return "Failed to fetch preset from AutoEQ. Please check your internet connection."
    case .invalidData:
      return "Invalid data received from AutoEQ"
    case .parseError:
      return "Failed to parse AutoEQ preset data"
    }
  }
}
