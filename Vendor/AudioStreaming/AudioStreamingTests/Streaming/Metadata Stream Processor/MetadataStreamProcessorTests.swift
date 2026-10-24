//
//  MetadataStreamProcessorTests.swift
//  AudioStreamingTests
//
//  Created by Dimitrios Chatzieleftheriou on 22/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

@testable import AudioStreaming

import XCTest

// MARK: - MetadataStreamProcessorTests

class MetadataStreamProcessorTests: XCTestCase {
  var metadataDelegateSpy = MetadataDelegateSpy()

  func test_Processor_SendsCorrectValues_IfItCanProcessMetadata() throws {
    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())

    // without calling `metadataAvailable(step:)` it should be false
    XCTAssertFalse(processor.canProcessMetadata)

    // calling `metadataAvailable(step:)` with zero
    processor.metadataAvailable(step: 0)

    // it should be false
    XCTAssertFalse(processor.canProcessMetadata)

    // calling `metadataAvailable(step:)` with greater zero
    processor.metadataAvailable(step: 1)

    // it should be true
    XCTAssertTrue(processor.canProcessMetadata)
  }

  func test_Processor_Outputs_Correct_Metadata_ForStep_WithEmptyMetadata() throws {
    let url = Bundle.module.url(
      forResource: "raw-audio-streams/raw-stream-audio-empty-metadata",
      withExtension: nil
    )!

    let data = try Data(contentsOf: url)

    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())
    processor.delegate = metadataDelegateSpy
    // this is the step value as received from the http headers
    processor.metadataAvailable(step: 16000)

    let audio = processor.processMetadata(data: data)
    XCTAssertFalse(audio.isEmpty)

    XCTAssertTrue(metadataDelegateSpy.receivedMetadata.called)
    XCTAssertEqual(metadataDelegateSpy.receivedMetadata.result, .success(["StreamTitle": ""]))
  }

  func test_Processor_Outputs_Correct_Metadata_ForStep_WithMetadata() throws {
    let url = Bundle.module.url(
      forResource: "raw-audio-streams/raw-stream-audio-normal-metadata",
      withExtension: nil
    )!

    let data = try Data(contentsOf: url)

    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())
    processor.delegate = metadataDelegateSpy
    // this is the step value as received from the http headers
    processor.metadataAvailable(step: 16000)

    let audio = processor.processMetadata(data: data)
    XCTAssertFalse(audio.isEmpty)

    XCTAssertTrue(metadataDelegateSpy.receivedMetadata.called)
    XCTAssertEqual(
      metadataDelegateSpy.receivedMetadata.result,
      .success(["StreamTitle": "Anomalie - Notre"])
    )
  }

  func test_Processor_Outputs_Correct_Metadata_ForStep_WithMetadata_Alt() throws {
    let url = Bundle.module.url(
      forResource: "raw-audio-streams/raw-stream-audio-normal-metadata-alt",
      withExtension: nil
    )!

    let data = try Data(contentsOf: url)

    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())
    processor.delegate = metadataDelegateSpy
    // this is the step value as received from the http headers
    processor.metadataAvailable(step: 8000)

    let audio = processor.processMetadata(data: data)
    XCTAssertFalse(audio.isEmpty)

    XCTAssertTrue(metadataDelegateSpy.receivedMetadata.called)
    guard case .success = metadataDelegateSpy.receivedMetadata.result else {
      XCTFail()
      return
    }
    XCTAssertNotNil(metadataDelegateSpy.receivedMetadata.result)
  }

  func test_Processor_Outputs_Correct_Metadata_ForStep_NoMetadata() throws {
    let url = Bundle.module.url(
      forResource: "raw-audio-streams/raw-stream-audio-no-metadata",
      withExtension: nil
    )!

    let data = try Data(contentsOf: url)

    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())
    processor.delegate = metadataDelegateSpy
    // this is the step value as received from the http headers
    processor.metadataAvailable(step: 16000)

    let audio = processor.processMetadata(data: data)
    XCTAssertFalse(audio.isEmpty)

    XCTAssertFalse(metadataDelegateSpy.receivedMetadata.called)
    XCTAssertNil(metadataDelegateSpy.receivedMetadata.result)
  }

  func test_Processor_Outputs_SameDataAsInput_ForEmptyData() throws {
    let data = Data()

    let parser = MetadataParser()
    let processor = MetadataStreamProcessor(parser: parser.eraseToAnyParser())
    processor.delegate = metadataDelegateSpy
    // this is the step value as received from the http headers
    processor.metadataAvailable(step: 16000)

    let audio = processor.processMetadata(data: data)
    XCTAssertTrue(audio.isEmpty)

    XCTAssertFalse(metadataDelegateSpy.receivedMetadata.called)
    XCTAssertNil(metadataDelegateSpy.receivedMetadata.result)
  }
}

// MARK: - MetadataDelegateSpy

class MetadataDelegateSpy: MetadataStreamSourceDelegate {
  var receivedMetadata: (called: Bool, result: Result<[String: String], MetadataParsingError>?) = (
    false,
    nil
  )
  func didReceiveMetadata(metadata: Result<[String: String], MetadataParsingError>) {
    receivedMetadata = (true, metadata)
  }
}
