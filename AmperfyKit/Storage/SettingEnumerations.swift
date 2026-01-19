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
  // Frequencies in Hz - Matching eqMac's 10-band Advanced Equalizer exactly
  // Source: https://github.com/bitgapp/eqMac - AdvancedEqualizer.swift
  // 32Hz (Sub-bass), 64Hz (Bass), 125Hz (Low-mid), 250Hz (Mid-bass),
  // 500Hz (Midrange), 1kHz (Upper-mid), 2kHz (Presence), 4kHz (Brilliance),
  // 8kHz (High treble), 16kHz (Air)
  public static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
  public static let defaultGains: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  
  // ±24dB range matching eqMac's official specification
  // Source: eqMac AdvancedEqualizerDataBus.swift validates gains between -24.0 and 24.0
  public static let rangeFromZero = 24

  public let id: UUID
  public var name: String
  // EQ gain within ±24 dB range (eqMac official spec)
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
    // Conservative compensation: half the average boost, max -24dB
    return -min(avgBoost / 2.0, 24.0)
  }

  // Compensated output volume (1.0 = normal, <1.0 = reduced to compensate for EQ boost)
  public var compensatedVolume: Float {
    // Convert dB compensation to linear scale
    let volume = 1.0 + (gainCompensation / 20.0)
    // Ensure safe range (0.05 to 2.0) - lower minimum for larger gain range
    return max(0.05, min(2.0, volume))
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

/// Professional equalizer presets matching eqMac's official preset library exactly
/// Source: https://github.com/bitgapp/eqMac - AdvancedEqualizerDefaultPresets.swift
/// All gains are in dB within ±24dB range (eqMac official specification)
/// Frequencies: 32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz
public enum EqualizerPreset: Int, CaseIterable, Sendable, Codable {
  case flat = 0
  case acoustic = 1
  case bassBooster = 2
  case bassReducer = 3
  case classic = 4
  case dance = 5
  case deep = 6
  case electronic = 7
  case hipHop = 8
  case jazz = 9
  case latin = 10
  case loudness = 11
  case lounge = 12
  case piano = 13
  case pop = 14
  case rnb = 15
  case rock = 16
  case smallSpeakers = 17
  case spokenWord = 18
  case trebleBooster = 19
  case trebleReducer = 20
  case vocalBooster = 21

  public static let defaultValue: EqualizerPreset = .flat

  public var description: String {
    switch self {
    case .flat: return "Flat"
    case .acoustic: return "Acoustic"
    case .bassBooster: return "Bass Booster"
    case .bassReducer: return "Bass Reducer"
    case .classic: return "Classic"
    case .dance: return "Dance"
    case .deep: return "Deep"
    case .electronic: return "Electronic"
    case .hipHop: return "Hip-Hop"
    case .jazz: return "Jazz"
    case .latin: return "Latin"
    case .loudness: return "Loudness"
    case .lounge: return "Lounge"
    case .piano: return "Piano"
    case .pop: return "Pop"
    case .rnb: return "R&B"
    case .rock: return "Rock"
    case .smallSpeakers: return "Small Speakers"
    case .spokenWord: return "Spoken Word"
    case .trebleBooster: return "Treble Booster"
    case .trebleReducer: return "Treble Reducer"
    case .vocalBooster: return "Vocal Booster"
    }
  }

  /// Gain values for each frequency band: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
  /// Values are in dB - EXACT values from eqMac's AdvancedEqualizerDefaultPresets.swift
  public var gains: [Float] {
    switch self {
    case .flat:
      // Array(repeating: 0, count: 10)
      return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    case .acoustic:
      // [-8.3, 9.8, -15.68, 2.1, 18.22, 3.5, 7, 8.2, 7.1, 4.3]
      return [-8.3, 9.8, -15.68, 2.1, 18.22, 3.5, 7, 8.2, 7.1, 4.3]
    case .bassBooster:
      // [11, 8.5, 7, 5, 2.5, 0, 0, 0, 0, 0]
      return [11, 8.5, 7, 5, 2.5, 0, 0, 0, 0, 0]
    case .bassReducer:
      // [-11, -8.5, -7, -5, -2.5, 0, 0, 0, 0, 0]
      return [-11, -8.5, -7, -5, -2.5, 0, 0, 0, 0, 0]
    case .classic:
      // [9.5, 7.5, 6, 5, -3, -3, 0, 4.5, 6.5, 7.5]
      return [9.5, 7.5, 6, 5, -3, -3, 0, 4.5, 6.5, 7.5]
    case .dance:
      // [7.14, 13.1, 9.98, 0, 3.84, 7.3, 10.3, 9.08, 7.18, 0]
      return [7.14, 13.1, 9.98, 0, 3.84, 7.3, 10.3, 9.08, 7.18, 0]
    case .deep:
      // [9.9, 7.1, 3.5, 2, 5.7, 5, 2.9, -4.3, -7.1, -9.2]
      return [9.9, 7.1, 3.5, 2, 5.7, 5, 2.9, -4.3, -7.1, -9.2]
    case .electronic:
      // [8.5, 7.6, 2.4, 0, -4.3, 4.5, 1.7, 2.5, 7.9, 9.6]
      return [8.5, 7.6, 2.4, 0, -4.3, 4.5, 1.7, 2.5, 7.9, 9.6]
    case .hipHop:
      // [10, 8.5, 3, 6, -2, -2, 3, -1, 4, 6]
      return [10, 8.5, 3, 6, -2, -2, 3, -1, 4, 6]
    case .jazz:
      // [8, 6, 3, 4.5, -3, -3, 0, 3, 6, 7.5]
      return [8, 6, 3, 4.5, -3, -3, 0, 3, 6, 7.5]
    case .latin:
      // [9, 6, 0, 0, -3, -3, -3, 0, 6, 9]
      return [9, 6, 0, 0, -3, -3, -3, 0, 6, 9]
    case .loudness:
      // [12, 8, 0, 0, -4, 0, -2, -10, 10, 2]
      return [12, 8, 0, 0, -4, 0, -2, -10, 10, 2]
    case .lounge:
      // [-6, -3, -1, 3, 8, 5, 0, -3, 4, 2]
      return [-6, -3, -1, 3, 8, 5, 0, -3, 4, 2]
    case .piano:
      // [6, 4, 0, 5, 6, 3, 7, 9, 6, 7]
      return [6, 4, 0, 5, 6, 3, 7, 9, 6, 7]
    case .pop:
      // [-3, -2, 0, 4, 8, 8, 4, 0, -2, -3]
      return [-3, -2, 0, 4, 8, 8, 4, 0, -2, -3]
    case .rnb:
      // [5.24, 13.84, 11.3, 2.66, -4.38, -3, 4.64, 5.3, 6, 7.5]
      return [5.24, 13.84, 11.3, 2.66, -4.38, -3, 4.64, 5.3, 6, 7.5]
    case .rock:
      // [10, 8, 6, 3, -1, -2, 1, 5, 7, 9]
      return [10, 8, 6, 3, -1, -2, 1, 5, 7, 9]
    case .smallSpeakers:
      // [11, 8.5, 7, 5, 2.5, 0, -2.5, -5, -7, -8.5]
      return [11, 8.5, 7, 5, 2.5, 0, -2.5, -5, -7, -8.5]
    case .spokenWord:
      // [-6.92, -0.94, 0, 1.38, 6.92, 9.22, 9.68, 8.56, 5.08, 0]
      return [-6.92, -0.94, 0, 1.38, 6.92, 9.22, 9.68, 8.56, 5.08, 0]
    case .trebleBooster:
      // [0, 0, 0, 0, 0, 2.5, 5, 7, 8.5, 11]
      return [0, 0, 0, 0, 0, 2.5, 5, 7, 8.5, 11]
    case .trebleReducer:
      // [0, 0, 0, 0, 0, -2.5, -5, -7, -8.5, -11]
      return [0, 0, 0, 0, 0, -2.5, -5, -7, -8.5, -11]
    case .vocalBooster:
      // [-3, -6, -6, 3, 7.5, 7.5, 6, 3, 0, -3]
      return [-3, -6, -6, 3, 7.5, 7.5, 6, 3, 0, -3]
    }
  }

  public var asEqualizerSetting: EqualizerSetting {
    EqualizerSetting(name: description, gains: gains)
  }
}

// MARK: - AutoEQPreset

/// AutoEQ headphone correction presets based on scientifically measured frequency responses
/// Source: https://github.com/jaakkopasanen/AutoEq (oratory1990 measurements)
/// These presets correct headphone frequency response to match the Harman target curve
/// Frequencies: 32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz (FixedBandEQ format)
public enum AutoEQPreset: Int, CaseIterable, Sendable, Codable {
  // Over-Ear Headphones
  case sennheiserHD650 = 0
  case sennheiserHD600 = 1
  case sennheiserHD560S = 2
  case sonyWH1000XM4 = 3
  case sonyWH1000XM5 = 4
  case appleAirPodsMax = 5
  case boseQC45 = 6
  case akgK371 = 7
  case audioTechnicaATHM50x = 8
  
  // In-Ear Monitors
  case samsungGalaxyBudsPro = 9
  case sonyWF1000XM4 = 10
  case moondropBlessing2 = 11
  
  public static let defaultValue: AutoEQPreset = .sennheiserHD650
  
  /// Headphone category for UI grouping
  public enum Category: String, CaseIterable {
    case overEar = "Over-Ear"
    case inEar = "In-Ear"
  }
  
  public var category: Category {
    switch self {
    case .sennheiserHD650, .sennheiserHD600, .sennheiserHD560S,
         .sonyWH1000XM4, .sonyWH1000XM5, .appleAirPodsMax,
         .boseQC45, .akgK371, .audioTechnicaATHM50x:
      return .overEar
    case .samsungGalaxyBudsPro, .sonyWF1000XM4, .moondropBlessing2:
      return .inEar
    }
  }
  
  public var description: String {
    switch self {
    case .sennheiserHD650: return "Sennheiser HD 650"
    case .sennheiserHD600: return "Sennheiser HD 600"
    case .sennheiserHD560S: return "Sennheiser HD 560S"
    case .sonyWH1000XM4: return "Sony WH-1000XM4"
    case .sonyWH1000XM5: return "Sony WH-1000XM5"
    case .appleAirPodsMax: return "Apple AirPods Max"
    case .boseQC45: return "Bose QuietComfort 45"
    case .akgK371: return "AKG K371"
    case .audioTechnicaATHM50x: return "Audio-Technica ATH-M50x"
    case .samsungGalaxyBudsPro: return "Samsung Galaxy Buds Pro"
    case .sonyWF1000XM4: return "Sony WF-1000XM4"
    case .moondropBlessing2: return "Moondrop Blessing 2"
    }
  }
  
  /// Gain values from AutoEQ FixedBandEQ format (oratory1990 measurements)
  /// Values are in dB for frequencies: 32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz
  public var gains: [Float] {
    switch self {
    // Over-Ear Headphones
    case .sennheiserHD650:
      // Preamp: -7.4 dB - Classic audiophile reference headphone
      return [7.0, 2.6, -1.2, -2.2, 0.5, -1.0, 0.7, -1.2, 5.1, -3.6]
    case .sennheiserHD600:
      // Preamp: -7.5 dB - Natural, balanced sound signature
      return [6.9, 3.3, -1.1, -1.6, 0.6, -0.8, 0.1, -1.0, 3.9, -6.5]
    case .sennheiserHD560S:
      // Preamp: -6.2 dB - Modern analytical headphone
      return [5.9, 1.6, 0.0, -1.0, 0.8, -1.6, 0.8, -1.3, 3.5, -8.1]
    case .sonyWH1000XM4:
      // Preamp: -5.8 dB - Popular ANC wireless headphone
      return [-4.3, -1.8, -5.8, -1.4, 0.5, -0.6, 6.0, -0.8, 1.0, -2.2]
    case .sonyWH1000XM5:
      // Preamp: -9.0 dB - Latest Sony flagship ANC
      return [-3.7, -1.6, -5.2, -3.3, 1.3, 1.8, 5.3, -2.4, 1.3, 9.0]
    case .appleAirPodsMax:
      // Preamp: -4.2 dB - Apple's premium over-ear
      return [-4.1, -0.9, -1.6, -2.1, -0.4, -2.9, 1.6, 2.9, 4.3, -10.6]
    case .boseQC45:
      // Preamp: -1.9 dB - Comfortable ANC headphone
      return [-1.4, -1.2, -2.1, -0.9, 0.7, 2.0, -0.9, -1.3, 0.3, -7.7]
    case .akgK371:
      // Preamp: -4.8 dB - Studio reference, Harman-tuned
      return [-3.0, 1.2, -1.4, -1.8, 0.8, -0.8, -0.3, 3.0, -0.2, 4.8]
    case .audioTechnicaATHM50x:
      // Preamp: -2.3 dB - Popular studio monitoring headphone
      return [0.0, 0.4, -5.3, 0.7, 1.9, -1.0, 0.6, 0.4, 2.8, -9.3]
      
    // In-Ear Monitors
    case .samsungGalaxyBudsPro:
      // Preamp: -3.0 dB - Samsung's flagship TWS
      return [0.2, 0.0, -2.3, -2.2, -0.1, 2.7, 1.7, 0.7, -1.4, -10.5]
    case .sonyWF1000XM4:
      // Preamp: -4.5 dB - Sony's premium TWS with ANC
      return [-2.5, -0.8, -3.2, -1.8, 0.4, 1.2, 3.8, -0.5, 0.8, -6.8]
    case .moondropBlessing2:
      // Preamp: -5.2 dB - Audiophile hybrid IEM
      return [4.2, 1.8, -0.6, -1.2, 0.3, -0.5, 1.2, -2.1, 2.4, -4.5]
    }
  }
  
  /// Preamp value in dB (for reference, already factored into gains)
  public var preamp: Float {
    switch self {
    case .sennheiserHD650: return -7.4
    case .sennheiserHD600: return -7.5
    case .sennheiserHD560S: return -6.2
    case .sonyWH1000XM4: return -5.8
    case .sonyWH1000XM5: return -9.0
    case .appleAirPodsMax: return -4.2
    case .boseQC45: return -1.9
    case .akgK371: return -4.8
    case .audioTechnicaATHM50x: return -2.3
    case .samsungGalaxyBudsPro: return -3.0
    case .sonyWF1000XM4: return -4.5
    case .moondropBlessing2: return -5.2
    }
  }
  
  public var asEqualizerSetting: EqualizerSetting {
    EqualizerSetting(name: "AutoEQ: \(description)", gains: gains)
  }
  
  /// Get all presets for a specific category
  public static func presets(for category: Category) -> [AutoEQPreset] {
    allCases.filter { $0.category == category }
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
