//
//  ParametricEQTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 19.07.25.
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

@testable import AmperfyKit
import XCTest

// MARK: - ParametricBandTests

final class ParametricBandTests: XCTestCase {
  // MARK: - Frequency Clamping

  func testFrequencyClampedToMinimum() {
    let band = ParametricBand(frequency: 10) // Below minimum of 20
    XCTAssertEqual(band.frequency, 20)
  }

  func testFrequencyClampedToMaximum() {
    let band = ParametricBand(frequency: 25000) // Above maximum of 20000
    XCTAssertEqual(band.frequency, 20000)
  }

  func testFrequencyWithinRange() {
    let band = ParametricBand(frequency: 1000)
    XCTAssertEqual(band.frequency, 1000)
  }

  // MARK: - Gain Clamping

  func testGainClampedToMinimum() {
    let band = ParametricBand(gain: -15) // Below minimum of -12
    XCTAssertEqual(band.gain, -12)
  }

  func testGainClampedToMaximum() {
    let band = ParametricBand(gain: 15) // Above maximum of 12
    XCTAssertEqual(band.gain, 12)
  }

  func testGainWithinRange() {
    let band = ParametricBand(gain: 6)
    XCTAssertEqual(band.gain, 6)
  }

  // MARK: - Q Clamping

  func testQClampedToMinimum() {
    let band = ParametricBand(q: 0.05) // Below minimum of 0.1
    XCTAssertEqual(band.q, 0.1)
  }

  func testQClampedToMaximum() {
    let band = ParametricBand(q: 15) // Above maximum of 10
    XCTAssertEqual(band.q, 10)
  }

  func testQWithinRange() {
    let band = ParametricBand(q: 2.0)
    XCTAssertEqual(band.q, 2.0)
  }

  // MARK: - Bandwidth Calculation

  func testBandwidthCalculation() {
    // Q = 1 should give bandwidth ≈ 1.386
    let band = ParametricBand(q: 1.0)
    XCTAssertEqual(band.bandwidth, 1.386, accuracy: 0.01)
  }

  func testBandwidthCalculationHighQ() {
    // Higher Q = narrower bandwidth
    let band = ParametricBand(q: 10.0)
    XCTAssertLessThan(band.bandwidth, 0.15)
  }

  func testBandwidthCalculationLowQ() {
    // Lower Q = wider bandwidth
    let band = ParametricBand(q: 0.5)
    XCTAssertGreaterThan(band.bandwidth, 2.0)
  }

  // MARK: - Default Values

  func testDefaultFilterType() {
    let band = ParametricBand()
    XCTAssertEqual(band.filterType, .bell)
  }

  func testDefaultBypass() {
    let band = ParametricBand()
    XCTAssertFalse(band.bypass)
  }
}

// MARK: - ParametricEqualizerSettingTests

final class ParametricEqualizerSettingTests: XCTestCase {
  // MARK: - Gain Compensation

  func testGainCompensationWithNoBoost() {
    let bands = [
      ParametricBand(gain: 0),
      ParametricBand(gain: -6),
      ParametricBand(gain: -3),
    ]
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    // No positive gains, so no compensation needed
    XCTAssertEqual(setting.gainCompensation, 0)
  }

  func testGainCompensationWithBoost() {
    let bands = [
      ParametricBand(gain: 6),
      ParametricBand(gain: 6),
      ParametricBand(gain: 0),
    ]
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    // Average boost is 6, so compensation should be -3 (half)
    XCTAssertEqual(setting.gainCompensation, -3)
  }

  func testGainCompensationMaxCap() {
    let bands = [
      ParametricBand(gain: 12),
      ParametricBand(gain: 12),
      ParametricBand(gain: 12),
    ]
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    // Max compensation is -12dB
    XCTAssertGreaterThanOrEqual(setting.gainCompensation, -12)
  }

  func testGainCompensationIgnoresBypassedBands() {
    let bands = [
      ParametricBand(gain: 12, bypass: true),
      ParametricBand(gain: 0),
    ]
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    // Bypassed band should be ignored
    XCTAssertEqual(setting.gainCompensation, 0)
  }

  // MARK: - Max Bands Limit

  func testMaxBandsLimit() {
    let bands = (0 ..< 15).map { _ in ParametricBand() }
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    XCTAssertEqual(setting.bands.count, 10)
  }

  // MARK: - Migration

  func testMigrationFromLegacySetting() {
    let legacy = EqualizerSetting(
      name: "Legacy Preset",
      gains: [3, 2, 1, 0, -1, -2, -3, -4, -5, -6]
    )

    let migrated = ParametricEqualizerSetting.migrate(from: legacy)

    XCTAssertEqual(migrated.name, "Legacy Preset")
    XCTAssertEqual(migrated.bands.count, 10)
    XCTAssertFalse(migrated.globalBypass)
  }

  func testMigrationPreservesGains() {
    let legacy = EqualizerSetting(
      name: "Test",
      gains: [6, 3, 0, -3, -6, 0, 0, 0, 0, 0]
    )

    let migrated = ParametricEqualizerSetting.migrate(from: legacy)

    XCTAssertEqual(migrated.bands[0].gain, 6)
    XCTAssertEqual(migrated.bands[1].gain, 3)
    XCTAssertEqual(migrated.bands[2].gain, 0)
    XCTAssertEqual(migrated.bands[3].gain, -3)
    XCTAssertEqual(migrated.bands[4].gain, -6)
  }

  func testMigrationSetsFilterTypes() {
    let legacy = EqualizerSetting(name: "Test", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

    let migrated = ParametricEqualizerSetting.migrate(from: legacy)

    // First band should be low shelf
    XCTAssertEqual(migrated.bands[0].filterType, .lowShelf)

    // Middle bands should be bell
    XCTAssertEqual(migrated.bands[1].filterType, .bell)
    XCTAssertEqual(migrated.bands[5].filterType, .bell)

    // Last band should be high shelf
    XCTAssertEqual(migrated.bands[9].filterType, .highShelf)
  }

  func testMigrationSetsDefaultFrequencies() {
    let legacy = EqualizerSetting(name: "Test", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

    let migrated = ParametricEqualizerSetting.migrate(from: legacy)

    XCTAssertEqual(migrated.bands[0].frequency, 32)
    XCTAssertEqual(migrated.bands[1].frequency, 64)
    XCTAssertEqual(migrated.bands[2].frequency, 125)
    XCTAssertEqual(migrated.bands[5].frequency, 1000)
    XCTAssertEqual(migrated.bands[9].frequency, 16000)
  }

  func testMigrationSetsDefaultQ() {
    let legacy = EqualizerSetting(name: "Test", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

    let migrated = ParametricEqualizerSetting.migrate(from: legacy)

    for band in migrated.bands {
      XCTAssertEqual(band.q, 1.0)
    }
  }
}

// MARK: - ParametricBandFilterTypeTests

final class ParametricBandFilterTypeTests: XCTestCase {
  func testBellFilterType() {
    XCTAssertEqual(ParametricBandFilterType.bell.avAudioUnitEQFilterType, .parametric)
  }

  func testLowShelfFilterType() {
    XCTAssertEqual(ParametricBandFilterType.lowShelf.avAudioUnitEQFilterType, .lowShelf)
  }

  func testHighShelfFilterType() {
    XCTAssertEqual(ParametricBandFilterType.highShelf.avAudioUnitEQFilterType, .highShelf)
  }

  func testFilterTypeDescriptions() {
    XCTAssertEqual(ParametricBandFilterType.bell.description, "Bell")
    XCTAssertEqual(ParametricBandFilterType.lowShelf.description, "Low Shelf")
    XCTAssertEqual(ParametricBandFilterType.highShelf.description, "High Shelf")
  }
}

// MARK: - CompensatedVolumeTests

final class CompensatedVolumeTests: XCTestCase {
  func testCompensatedVolumeWithNoCompensation() {
    let setting = ParametricEqualizerSetting(name: "Flat", bands: [])
    XCTAssertEqual(setting.compensatedVolume, 1.0, accuracy: 0.01)
  }

  func testCompensatedVolumeWithNegativeCompensation() {
    let bands = [
      ParametricBand(gain: 12),
      ParametricBand(gain: 12),
    ]
    let setting = ParametricEqualizerSetting(name: "Test", bands: bands)

    // With -6dB compensation, volume should be reduced
    XCTAssertLessThan(setting.compensatedVolume, 1.0)
  }

  func testCompensatedVolumeStaysInRange() {
    // Test various gain configurations
    let extremeBoost = ParametricEqualizerSetting(
      name: "Extreme",
      bands: (0 ..< 10).map { _ in ParametricBand(gain: 12) }
    )

    XCTAssertGreaterThanOrEqual(extremeBoost.compensatedVolume, 0.1)
    XCTAssertLessThanOrEqual(extremeBoost.compensatedVolume, 2.0)
  }
}
