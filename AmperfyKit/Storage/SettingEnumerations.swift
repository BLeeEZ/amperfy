//
//  SettingEnumerations.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation
import os.log
import SwiftUI
import UIKit

// MARK: - ArtworkDownloadSetting

public enum ArtworkDownloadSetting: Int, CaseIterable, Sendable, Codable {
  case updateOncePerSession = 0
  case onlyOnce = 1
  case never = 2

  static let defaultValue: ArtworkDownloadSetting = .onlyOnce

  public var description: String {
    switch self {
    case .updateOncePerSession:
      return "Download once per session (change detection)"
    case .onlyOnce:
      return "Download only once"
    case .never:
      return "Never"
    }
  }
}

// MARK: - ArtworkDisplayPreference

public enum ArtworkDisplayPreference: Int, CaseIterable, Sendable, Codable {
  case id3TagOnly = 0
  case serverArtworkOnly = 1
  case preferServerArtwork = 2
  case preferId3Tag = 3

  public static let defaultValue: ArtworkDisplayPreference = .preferId3Tag

  public var description: String {
    switch self {
    case .id3TagOnly:
      return "Only ID3 tag artworks"
    case .serverArtworkOnly:
      return "Only server artworks"
    case .preferServerArtwork:
      return "Prefer server artwork over ID3 tag"
    case .preferId3Tag:
      return "Prefer ID3 tag over server artwork"
    }
  }
}

// MARK: - ScreenLockPreventionPreference

public enum ScreenLockPreventionPreference: Int, CaseIterable, Sendable, Codable {
  case always = 0
  case never = 1
  case onlyIfCharging = 2

  public static let defaultValue: ScreenLockPreventionPreference = .never

  public var description: String {
    switch self {
    case .always:
      return "Always"
    case .never:
      return "Never"
    case .onlyIfCharging:
      return "When connected to charger"
    }
  }
}

// MARK: - StreamingMaxBitratePreference

public enum StreamingMaxBitratePreference: Int, CaseIterable, Sendable, Codable {
  case noLimit = 0
  case limit32 = 32
  case limit64 = 64
  case limit96 = 96
  case limit128 = 128
  case limit192 = 192
  case limit256 = 256
  case limit320 = 320

  public static let defaultValue: StreamingMaxBitratePreference = .noLimit

  public var description: String {
    switch self {
    case .noLimit:
      return "No Limit (default)"
    default:
      return "\(rawValue) kbps"
    }
  }

  public var asBitsPerSecondAV: Double {
    Double(rawValue * 1000)
  }
}

// MARK: - StreamingFormatPreference

public enum StreamingFormatPreference: Int, CaseIterable, Sendable, Codable {
  case mp3 = 0
  case raw = 1
  case serverConfig = 2 // omit the format to let the server decide which codec should be used

  public static let defaultValue: StreamingFormatPreference = .mp3

  public var shortInfo: String {
    switch self {
    case .mp3:
      return "MP3"
    case .raw:
      return "RAW"
    case .serverConfig:
      return ""
    }
  }

  public var description: String {
    switch self {
    case .mp3:
      return "mp3 (default)"
    case .raw:
      return "Raw/Original"
    case .serverConfig:
      return "Server chooses Codec"
    }
  }
}

// MARK: - EqualizerBand

public struct EqualizerBand: Hashable, Sendable, Codable {
  public enum FilterType: Int, Codable, CaseIterable, Sendable {
    case parametric = 0
    case lowShelf = 1
    case highShelf = 2
    case lowPass = 3
    case highPass = 4
  }

  public var frequency: Float
  public var gain: Float
  public var bandwidth: Float // Bandwidth in octaves or Q
  public var filterType: FilterType
  public var bypass: Bool

  public init(
    frequency: Float,
    gain: Float = 0.0,
    bandwidth: Float = 1.0,
    filterType: FilterType = .parametric,
    bypass: Bool = false
  ) {
    self.frequency = frequency
    self.gain = gain
    self.bandwidth = bandwidth
    self.filterType = filterType
    self.bypass = bypass
  }
}

// MARK: - EqualizerSetting

public struct EqualizerSetting: Hashable, Sendable, Codable {
  // Fixed frequencies for legacy 10-band EQ
  public static let legacyFrequencies: [Float] = [
    32,
    64,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000
  ]
  public static let legacyRangeFromZero = 6

  public let id: UUID
  public var name: String
  public var bands: [EqualizerBand]
  public var preamp: Float
  public var headphoneModel: String?

  public init(
    id: UUID = UUID(),
    name: String,
    bands: [EqualizerBand],
    preamp: Float = 0.0,
    headphoneModel: String? = nil
  ) {
    self.id = id
    self.name = name
    self.bands = bands
    self.preamp = preamp
    self.headphoneModel = headphoneModel
  }

  // Legacy initializer for 10-band EQ
  public init(name: String, gains: [Float], preamp: Float = 0.0) {
    self.id = UUID()
    self.name = name
    self.bands = zip(Self.legacyFrequencies, gains).map { frequency, gain in
      EqualizerBand(frequency: frequency, gain: gain, bandwidth: 1.414)
    }
    self.preamp = preamp
    self.headphoneModel = nil
  }

  public var description: String {
    name
  }

  public static let off: EqualizerSetting = .init(
    name: "Off",
    bands: legacyFrequencies.map { EqualizerBand(frequency: $0) }
  )

  public static let basicPresets: [EqualizerSetting] = [
    .init(name: "Acoustic", gains: [0, 1.5, 3, 1, 1, 1, 1.5, 3, 2, 1], preamp: -3.0),
    .init(name: "Bass Booster", gains: [3, 4, 3, 2, 1, 0, 0, 0, 0, 0], preamp: -4.0),
    .init(name: "Bass Reducer", gains: [-3, -4, -3, -2, -1, 0, 0, 0, 0, 0], preamp: 0.0),
    .init(name: "Classical", gains: [0, 0, 0, 0, 0, 0, -1, -2, -2, -3], preamp: 0.0),
    .init(name: "Dance", gains: [3, 4, 1, 0, 0, -2, -4, -4, 0, 0], preamp: -4.0),
    .init(name: "Electronic", gains: [3, 2, 0, -1, -2, 0, 1, 2, 3, 4], preamp: -4.0),
    .init(name: "Funk", gains: [1.5, 1, 0, 1, 2, 3, 2, 1, 1, 1.5], preamp: -3.0),
    .init(name: "Hip-Hop", gains: [3, 2, 0, 1, -1, -1, 0, 1, 2, 3], preamp: -3.0),
    .init(name: "Jazz", gains: [2, 1, 0, 1, -1, -1, 0, 1, 2, 3], preamp: -3.0),
    .init(name: "Pop", gains: [-1, -1, 0, 1, 2, 2, 1, 0, -1, -1], preamp: -2.0),
    .init(name: "Rock", gains: [3, 2, 1, 0, -1, -1, 0, 1, 2, 3], preamp: -3.0)
  ]

  // Automatic gain compensation (stubbed out to rely on manual preamp)
  public var gainCompensation: Float {
    return 0.0
  }

  // Compensated output volume (1.0 = normal, <1.0 = reduced to compensate for EQ boost)
  public var compensatedVolume: Float {
    // Convert dB compensation to linear scale: 10^(dB/20)
    pow(10, (preamp + gainCompensation) / 20.0)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public static func == (
    lhs: EqualizerSetting,
    rhs: EqualizerSetting
  )
    -> Bool {
    lhs.id == rhs.id
  }

  // Compatibility helper for old UI
  public var legacyGains: [Float] {
    get {
      return Self.legacyFrequencies.map { freq in
        let tolerance = freq * 0.25 // Increased tolerance to ensure matching
        return bands.first(where: { abs($0.frequency - freq) < tolerance })?.gain ?? 0
      }
    }
    set {
      // Update existing bands or create new ones
      for (index, gain) in newValue.enumerated() {
        if index < bands.count {
          bands[index].gain = gain
        } else if index < Self.legacyFrequencies.count {
          bands.append(EqualizerBand(frequency: Self.legacyFrequencies[index], gain: gain))
        }
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case id, name, bands, preamp, headphoneModel
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    bands = try container.decode([EqualizerBand].self, forKey: .bands)
    preamp = try container.decodeIfPresent(Float.self, forKey: .preamp) ?? 0.0
    headphoneModel = try container.decodeIfPresent(String.self, forKey: .headphoneModel)
  }

  // MARK: - Parametric Format (AutoEQ style)

  public var parametricFormat: String {
    var output = "Preamp: \(String(format: "%.1f", preamp)) dB\n"
    for (index, band) in bands.enumerated() {
      let typeStr: String = switch band.filterType {
      case .parametric: "PK"
      case .lowShelf: "LS"
      case .highShelf: "HS"
      case .lowPass: "LP"
      case .highPass: "HP"
      }
      output += "Filter \(index + 1): \(band.bypass ? "OFF" : "ON") \(typeStr) Fc \(Int(band.frequency)) Hz Gain \(String(format: "%.1f", band.gain)) dB Q \(String(format: "%.2f", band.bandwidth))\n"
    }
    return output
  }

  public static func parseParametric(text: String, name: String = "Imported EQ") -> EqualizerSetting? {
    var bands = [EqualizerBand]()
    var preamp: Float = 0.0
    let lines = text.components(separatedBy: .newlines)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { continue }

      if trimmed.lowercased().starts(with: "preamp") {
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 {
          let valStr = parts[1].replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)
          if let p = Float(valStr) {
            preamp = p
          }
        }
      } else if trimmed.lowercased().starts(with: "filter") {
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var freq: Float?
        var gain: Float?
        var q: Float?
        var type: EqualizerBand.FilterType = .parametric
        var bypass = false

        if let onOffIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("ON") == .orderedSame || $0.caseInsensitiveCompare("OFF") == .orderedSame }) {
          bypass = parts[onOffIndex].caseInsensitiveCompare("OFF") == .orderedSame
          
          if parts.indices.contains(onOffIndex + 1) {
            let typeStr = parts[onOffIndex + 1].uppercased()
            switch typeStr {
            case "PK": type = .parametric
            case "LS": type = .lowShelf
            case "HS": type = .highShelf
            case "LP": type = .lowPass
            case "HP": type = .highPass
            default: type = .parametric
            }
          }
        }

        func parseNumber(_ s: String) -> Float? {
          let filtered = s.filter { "0123456789.-".contains($0) }
          return Float(filtered)
        }

        if let fcIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("Fc") == .orderedSame }), parts.indices.contains(fcIndex + 1) {
          freq = parseNumber(parts[fcIndex + 1])
        }
        if let gainIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("Gain") == .orderedSame }), parts.indices.contains(gainIndex + 1) {
          gain = parseNumber(parts[gainIndex + 1])
        }
        if let qIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("Q") == .orderedSame }), parts.indices.contains(qIndex + 1) {
          q = parseNumber(parts[qIndex + 1])
        }

        if let f = freq, let g = gain, let b = q {
          bands.append(EqualizerBand(frequency: f, gain: g, bandwidth: b, filterType: type, bypass: bypass))
        }
      }
    }

    if bands.isEmpty { return nil }
    return EqualizerSetting(name: name, bands: bands, preamp: preamp)
  }
}

// MARK: - AutoEqService

public struct AutoEqHeadphone: Codable, Hashable, Sendable {
  public let name: String
  public let path: String
  public let author: String?
}

@MainActor
public final class AutoEqService {
  public static let shared = AutoEqService()
  private let baseURL = URL(string: "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/")!

  private init() {}

  public func fetchHeadphoneIndex() async throws -> [AutoEqHeadphone] {
    let indexURL = baseURL.appendingPathComponent("INDEX.md")
    let (data, _) = try await URLSession.shared.data(from: indexURL)
    guard let content = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: "AutoEqService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode INDEX.md"]
      )
    }

    // Parse INDEX.md (markdown list)
    // Format: - [Name](./path/to/results) by Author on Source
    var headphones = [AutoEqHeadphone]()
    let lines = content.components(separatedBy: .newlines)
    
    // Regular expression to match: - [Name](./Path) by Author
    // Group 1: Name, Group 2: Path (after ./), Group 3: Optional Author info
    // We use a non-greedy name match and a greedy path match followed by the closing paren of the link.
    // The closing paren of the link is identifying as being followed by a space or end-of-line.
    let pattern = #"^- \[(.*?)\]\(\.\/(.*)\)(?=\s|$)(?:\s+(.*)|)$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return []
    }

    for line in lines {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, options: [], range: range) {
            let nameRange = Range(match.range(at: 1), in: line)!
            let pathRange = Range(match.range(at: 2), in: line)!
            
            let name = String(line[nameRange])
            let rawPath = String(line[pathRange])
            
            // Normalize path: decode any %20 etc, then we re-encode correctly in fetchPreset
            let path = rawPath.removingPercentEncoding ?? rawPath
            
            var author: String? = nil
            if match.numberOfRanges >= 4, let r = Range(match.range(at: 3), in: line), !line[r].isEmpty {
                let extra = String(line[r])
                if let byRange = extra.range(of: "by ") {
                    let afterBy = extra[byRange.upperBound...]
                    if let onRange = afterBy.range(of: " on ") {
                        author = String(afterBy[..<onRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    } else {
                        author = String(afterBy).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            headphones.append(AutoEqHeadphone(name: name, path: path, author: author))
        }
    }
    return headphones
  }

  public func fetchPreset(for headphone: AutoEqHeadphone) async throws -> EqualizerSetting {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "+")
    
    guard let encodedPath = headphone.path.addingPercentEncoding(withAllowedCharacters: allowed) else {
      throw NSError(domain: "AutoEqService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL Path"])
    }
    
    // AutoEQ results often prefix the headphone name to the filename.
    // We try the prefixed version first, then fallback to generic ParametricEQ.txt
    let filenames = ["\(headphone.name) ParametricEQ.txt", "ParametricEQ.txt"]
    
    var lastError: Error?
    for filename in filenames {
      guard let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: allowed),
            let presetURL = URL(string: encodedPath + "/" + encodedFilename, relativeTo: baseURL) else {
        continue
      }
      
      os_log(.debug, "AutoEQ: Trying (v2) %{public}@", presetURL.absoluteString)
      
      do {
        let (data, response) = try await URLSession.shared.data(from: presetURL)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
          guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AutoEqService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode content"])
          }
          return EqualizerSetting.parseParametric(text: content, name: headphone.name) ?? EqualizerSetting(name: headphone.name, bands: [], preamp: 0.0)
        } else if let httpResponse = response as? HTTPURLResponse {
          os_log(.debug, "AutoEQ: %{public}@ returned %d", filename, httpResponse.statusCode)
        }
      } catch {
        os_log(.error, "AutoEQ: Error fetching %{public}@: %{public}@", filename, error.localizedDescription)
        lastError = error
      }
    }
    
    throw lastError ?? NSError(domain: "AutoEqService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch preset from any known filename"])
  }
}

public enum EqualizerPreset: Int, CaseIterable, Sendable, Codable {
  case off = 0
  case increasedBass = 1
  case reducedBass = 2
  case increasedTreble = 3
  case hipHop = 4
  case funk = 5
  case electronic = 6
  case classical = 7
  case rock = 8
  case pop = 9

  public static let defaultValue: EqualizerPreset = .off

  public var description: String {
    switch self {
    case .off: return "Off"
    case .increasedBass: return "Increased Bass"
    case .reducedBass: return "Reduced Bass"
    case .increasedTreble: return "Increased Treble"
    case .hipHop: return "Hip Hop"
    case .funk: return "Funk"
    case .electronic: return "Electronic"
    case .classical: return "Classical"
    case .rock: return "Rock"
    case .pop: return "Pop"
    }
  }

  public var bands: [EqualizerBand] {
    switch self {
    case .off:
      return EqualizerSetting.legacyFrequencies.map { EqualizerBand(frequency: $0) }
    case .increasedBass:
      return zip(EqualizerSetting.legacyFrequencies, [5, 4, 3, 2, 0, -1, -2, -3, -3, -3]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .reducedBass:
      return zip(EqualizerSetting.legacyFrequencies, [-3, -2, -1, -1, 0, 0, 0, 0, 0, 0]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .increasedTreble:
      return zip(EqualizerSetting.legacyFrequencies, [0, 0, 0, 0, 1, 2, 3, 4, 5, 6]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .hipHop:
      return zip(EqualizerSetting.legacyFrequencies, [4, 3, 1, 2, 1, 1, 2, 1, 2, 3]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .funk:
      return zip(EqualizerSetting.legacyFrequencies, [-1, 0, 2, 3, 2, 1, 2, 2, 1, 0]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .electronic:
      return zip(EqualizerSetting.legacyFrequencies, [4, 3, 0, 0, -1, 0, 1, 1, 3, 4]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .classical:
      return zip(EqualizerSetting.legacyFrequencies, [4, 3, 2, 1, 0, 0, 0, 1, 2, 3]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .rock:
      return zip(EqualizerSetting.legacyFrequencies, [3, 2, -1, -2, -1, 0, 2, 3, 3, 3]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    case .pop:
      return zip(EqualizerSetting.legacyFrequencies, [-1, -1, 0, 2, 3, 3, 2, -1, -1, -1]).map {
        EqualizerBand(frequency: $0, gain: $1)
      }
    }
  }

  public var asEqualizerSetting: EqualizerSetting {
    EqualizerSetting(name: description, bands: bands)
  }
}

// MARK: - SyncCompletionStatus

public enum SyncCompletionStatus: Int, CaseIterable, Sendable, Codable {
  case completed = 0
  case skipped = 1
  case aborded = 2

  public static let defaultValue: SyncCompletionStatus = .completed

  public var description: String {
    switch self {
    case .completed:
      return "Completed"
    case .skipped:
      return "Skipped"
    case .aborded:
      return "Aborded"
    }
  }
}

// MARK: - ThemePreference

public enum ThemePreference: Int, CaseIterable, Sendable, Codable {
  case blue = 0
  case green = 1
  case red = 2
  case yellow = 3
  case orange = 4
  case purple = 5

  public static let defaultValue: ThemePreference = .blue

  public var description: String {
    switch self {
    case .blue:
      return "Blue"
    case .green:
      return "Green"
    case .red:
      return "Red"
    case .yellow:
      return "Yellow"
    case .orange:
      return "Orange"
    case .purple:
      return "Purple"
    }
  }

  public var asColor: UIColor {
    switch self {
    case .blue:
      return .systemBlue
    case .green:
      return .systemGreen
    case .red:
      return .systemRed
    case .yellow:
      return .systemYellow
    case .orange:
      return .systemOrange
    case .purple:
      return .systemPurple
    }
  }

  public var contrastColor: UIColor {
    switch self {
    case .blue:
      return .white
    case .green:
      return .white
    case .red:
      return .white
    case .yellow:
      return .black
    case .orange:
      return .white
    case .purple:
      return .white
    }
  }
}

// MARK: - CacheTranscodingFormatPreference

public enum CacheTranscodingFormatPreference: Int, CaseIterable, Sendable, Codable {
  case raw = 0
  case mp3 = 1
  case serverConfig = 2 // omit the format to let the server decide which codec should be used

  public static let defaultValue: CacheTranscodingFormatPreference = .mp3

  public var description: String {
    switch self {
    case .mp3:
      return "mp3 (default)"
    case .raw:
      return "Raw/Original"
    case .serverConfig:
      return "Server chooses Codec"
    }
  }
}

// MARK: - VisualizerType

public enum VisualizerType: String, CaseIterable, Sendable, Codable {
  case ring
  case waveform
  case spectrumBars
  case generativeArt
  
  public static let defaultValue: VisualizerType = .ring

  public var displayName: String {
    switch self {
    case .ring: return "Ring"
    case .waveform: return "Waveform"
    case .spectrumBars: return "Spectrum Bars"
    case .generativeArt: return "Generative Art"
    }
  }

  public var iconName: String {
    switch self {
    case .ring: return "circle.dashed"
    case .waveform: return "waveform.path"
    case .spectrumBars: return "chart.bar.fill"
    case .generativeArt: return "sparkles"
    }
  }
}


// MARK: - UIUserInterfaceStyle

extension UIUserInterfaceStyle: @retroactive Encodable, @retroactive Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(Int.self)
    self = UIUserInterfaceStyle(rawValue: raw) ?? .unspecified
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
