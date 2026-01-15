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

// MARK: - EqualizerSetting

public struct EqualizerSetting: Hashable, Sendable, Codable {
  // Frequencies in Hz
  public static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
  public static let defaultGains: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  public static let rangeFromZero = 6

  public let id: UUID
  public var name: String
  // EQ gain within 6 dB range
  public var gains: [Float]

  public init(id: UUID = UUID(), name: String, gains: [Float] = Self.defaultGains) {
    self.id = id
    self.name = name
    self.gains = gains
  }

  public var description: String {
    name
  }

  public static let off: EqualizerSetting = .init(name: "Off", gains: Self.defaultGains)

  // Automatic gain compensation to maintain consistent volume levels
  public var gainCompensation: Float {
    let positiveGains = gains.filter { $0 > 0 }
    let avgBoost = positiveGains.isEmpty ? 0 : positiveGains
      .reduce(0, +) / Float(positiveGains.count)
    // Conservative compensation: half the average boost, max -6dB
    return -min(avgBoost / 2.0, 6.0)
  }

  // Compensated output volume (1.0 = normal, <1.0 = reduced to compensate for EQ boost)
  public var compensatedVolume: Float {
    // Convert dB compensation to linear scale
    let volume = 1.0 + (gainCompensation / 20.0)
    // Ensure safe range (0.1 to 2.0)
    return max(0.1, min(2.0, volume))
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
}

// MARK: - EqualizerPreset

public enum EqualizerPreset: Int, CaseIterable, Sendable, Codable {
  case off = 0
  case increasedBass = 1
  case reducedBass = 2
  case increasedTreble = 3

  public static let defaultValue: EqualizerPreset = .off

  public var description: String {
    switch self {
    case .off: return "Off"
    case .increasedBass: return "Increased Bass"
    case .reducedBass: return "Reduced Bass"
    case .increasedTreble: return "Increased Treble"
    }
  }

  public var gains: [Float] {
    switch self {
    case .off: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    case .increasedBass: return [5, 4, 3, 2, 0, -1, -2, -3, -3, -3]
    case .reducedBass: return [-3, -2, -1, -1, 0, 0, 0, 0, 0, 0]
    case .increasedTreble: return [0, 0, 0, 0, 1, 2, 3, 4, 5, 6]
    }
  }

  public var asEqualizerSetting: EqualizerSetting {
    EqualizerSetting(name: description, gains: gains)
  }
}

// MARK: - SyncCompletionStatus

public enum SyncCompletionStatus: Int, CaseIterable, Sendable, Codable {
  case completed = 0
  case skipped = 1
  case aborted = 2

  public static let defaultValue: SyncCompletionStatus = .completed

  public var description: String {
    switch self {
    case .completed:
      return "Completed"
    case .skipped:
      return "Skipped"
    case .aborted:
      return "Aborted"
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

  public var asSwiftUIColor: Color {
    switch self {
    case .blue:
      return .blue
    case .green:
      return .green
    case .red:
      return .red
    case .yellow:
      return .yellow
    case .orange:
      return .orange
    case .purple:
      return .purple
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
