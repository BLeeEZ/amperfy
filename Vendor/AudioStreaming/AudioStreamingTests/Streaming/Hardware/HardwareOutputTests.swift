@testable import AudioStreaming
import XCTest

final class HardwareOutputTests: XCTestCase {
  func testStereoAndMonoTracksPlayAsStereo() {
    XCTAssertEqual(HardwareOutput.channelCount(forSourceChannels: 1, canonicalChannels: 6), 2)
    XCTAssertEqual(HardwareOutput.channelCount(forSourceChannels: 2, canonicalChannels: 6), 2)
  }

  func testMultichannelTracksPlayInTheCanonicalLayout() {
    XCTAssertEqual(HardwareOutput.channelCount(forSourceChannels: 6, canonicalChannels: 6), 6)
    XCTAssertEqual(HardwareOutput.channelCount(forSourceChannels: 4, canonicalChannels: 6), 6)
  }

  func testUnknownSourceKeepsNoPreference() {
    XCTAssertNil(HardwareOutput.channelCount(forSourceChannels: 0, canonicalChannels: 6))
  }

  func testCopiesTheFrontPairOfInterleaved51() {
    // Two frames of L R C LFE Ls Rs.
    let source: [Float] = [1, 2, 3, 4, 5, 6, 11, 12, 13, 14, 15, 16]
    var stereo = [Float](repeating: 0, count: 4)
    source.withUnsafeBufferPointer { src in
      stereo.withUnsafeMutableBufferPointer { dst in
        HardwareOutput.copyFrontPair(
          from: src.baseAddress!,
          sourceChannels: 6,
          to: dst.baseAddress!,
          frames: 2
        )
      }
    }
    XCTAssertEqual(stereo, [1, 2, 11, 12])
  }
}
