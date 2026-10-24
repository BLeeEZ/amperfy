//
//  Created by Dimitrios Chatzieleftheriou on 26/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

@testable import AudioStreaming
import XCTest

class NetworkingClientTests: XCTestCase {
  func testInitialiseCorrectly() throws {
    let networking = NetworkingClient()

    XCTAssertNotNil(networking.session.delegate)
    XCTAssert(networking.delegate === networking.session.delegate)
  }

  func testInitialiseCorrectlyWithCustomArguments() {
    let configuration = URLSessionConfiguration.default
    let delegate = NetworkSessionDelegate()
    let queue = DispatchQueue(label: "temp.queue")

    let networking = NetworkingClient(
      configuration: configuration,
      delegate: delegate,
      networkQueue: queue
    )

    XCTAssertNotNil(networking.session)
    XCTAssertTrue(networking.delegate === networking.session.delegate)
    XCTAssertTrue(networking.networkQueue == queue)
  }

  func testShouldStartRequestImmediatelly() {
    let networking = NetworkingClient()
    let url = URL(string: "https://httpbun.com/get")!
    let request = URLRequest(url: url)

    let expectation = expectation(description: "\(url)")

    var responseCompletion: NetworkDataStream.Completion?
    var receivedData: Data?

    networking.stream(request: request)
      .responseStream { event in
        switch event {
        case let .stream(result):
          switch result {
          case let .success(value):
            receivedData = value.data
          case .failure: break
          }
        case let .complete(completion):
          responseCompletion = completion
          expectation.fulfill()
        case .response:
          break
        }
      }
      .resume()

    waitForExpectations(timeout: 10, handler: nil)

    XCTAssertEqual(responseCompletion?.response?.statusCode, 200)
    XCTAssertNotNil(responseCompletion)
    XCTAssertNotNil(receivedData)
  }
}
