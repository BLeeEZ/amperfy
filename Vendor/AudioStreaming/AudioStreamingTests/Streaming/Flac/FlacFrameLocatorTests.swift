@testable import AudioStreaming
import XCTest

/// Frame positions of sine-noise-5.1-48k.flac, from `flac --analyze`.
private let frameOffsets = [
  8328,
  34414,
  60483,
  86497,
  112_506,
  138_571,
  164_610,
  190_647,
  216_674,
  242_709,
  268_746,
  294_834,
]

// MARK: - FlacFrameLocatorTests

final class FlacFrameLocatorTests: XCTestCase {
  private var bytes: [UInt8] = []

  override func setUpWithError() throws {
    let url = try XCTUnwrap(Bundle.module.url(
      forResource: "sine-noise-5.1-48k",
      withExtension: "flac"
    ))
    bytes = try [UInt8](Data(contentsOf: url))
  }

  func testFindsTheFirstFrameAfterAnArbitraryOffset() {
    for (index, offset) in frameOffsets.enumerated().dropLast() {
      let start = offset + 100 // somewhere inside frame `index`
      let frame = FlacFrameLocator.firstFrame(
        in: bytes[start...],
        channels: 6,
        sampleRate: 48000,
        blockSize: 4096
      )
      XCTAssertEqual(frame, FlacFrameLocator.Frame(
        offset: frameOffsets[index + 1] - start,
        firstSample: Int64(index + 1) * 4096
      ))
    }
  }

  func testFindsAFrameThatStartsTheSlice() {
    let frame = FlacFrameLocator.firstFrame(
      in: bytes[frameOffsets[3]...],
      channels: 6,
      sampleRate: 48000,
      blockSize: 4096
    )
    XCTAssertEqual(frame, FlacFrameLocator.Frame(offset: 0, firstSample: 3 * 4096))
  }

  func testRejectsHeadersForAnotherStreamLayout() {
    XCTAssertNil(FlacFrameLocator.firstFrame(
      in: bytes[frameOffsets[3] ..< frameOffsets[3] + 64],
      channels: 2,
      sampleRate: 48000,
      blockSize: 4096
    ))
    XCTAssertNil(FlacFrameLocator.firstFrame(
      in: bytes[frameOffsets[3] ..< frameOffsets[3] + 64],
      channels: 6,
      sampleRate: 44100,
      blockSize: 4096
    ))
  }

  func testNeedsTheWholeHeader() {
    XCTAssertNil(FlacFrameLocator.firstFrame(
      in: bytes[frameOffsets[3] ..< frameOffsets[3] + 4],
      channels: 6,
      sampleRate: 48000,
      blockSize: 4096
    ))
  }
}
