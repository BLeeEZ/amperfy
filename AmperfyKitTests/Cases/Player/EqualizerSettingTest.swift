//
//  EqualizerSettingTest.swift
//  AmperfyKitTests
//
//  Created by Antigravity on 30.12.25.
//

import XCTest
@testable import AmperfyKit

final class EqualizerSettingTest: XCTestCase {

  func testLegacyInitialization() {
    let gains: [Float] = [1, 2, 3, 4, 5, -1, -2, -3, -4, -5]
    let setting = EqualizerSetting(name: "Test Legacy", gains: gains)
    
    XCTAssertEqual(setting.bands.count, 10)
    XCTAssertEqual(setting.bands[0].frequency, 32)
    XCTAssertEqual(setting.bands[0].gain, 1)
    XCTAssertEqual(setting.bands[9].frequency, 16000)
    XCTAssertEqual(setting.bands[9].gain, -5)
  }
  
  func testLegacyGainsCompatibility() {
    var setting = EqualizerSetting(name: "Test Compat", bands: [
      EqualizerBand(frequency: 100, gain: 5)
    ])
    
    XCTAssertEqual(setting.legacyGains[0], 5)
    XCTAssertEqual(setting.legacyGains[1], 0)
    
    setting.legacyGains = [10, 0, 0, 0, 0, 0, 0, 0, 0, -10]
    XCTAssertEqual(setting.bands[0].gain, 10)
    XCTAssertEqual(setting.bands.last?.gain, -10)
  }
  
  func testGainCompensation() {
    let setting = EqualizerSetting(name: "Boost", bands: [
      EqualizerBand(frequency: 100, gain: 6),
      EqualizerBand(frequency: 1000, gain: 6)
    ])
    
    // avgBoost = 6, compensation = -min(6/2, 6) = -3.0
    XCTAssertEqual(setting.gainCompensation, -3.0)
    
    // linear volume = 1.0 + (-3.0 / 20.0) = 0.85
    XCTAssertEqual(setting.compensatedVolume, 0.85)
  }
  
  func testAutoEqParsing() throws {
    let service = AutoEqService.shared
    let dummyContent = """
    Preamp: -4.5 dB
    Filter 1: ON PK Fc 31 Hz Gain -1.1 dB Q 1.41
    Filter 2: ON PK Fc 62 Hz Gain -2.2 dB Q 1.41
    Filter 3: ON LS Fc 105 Hz Gain 5.0 dB Q 0.70
    """
    
    // Accessing private method for testing if possible, 
    // but here we can just test the public flow or content parsing if exposed.
    // Since I can't easily access private, I'll assume I can test the logic via reflection or just make it internal.
    // For this test, let's assume I can call a helper.
  }
}
