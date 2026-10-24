//
//  Created by Dimitrios Chatzieleftheriou on 22/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - NetworkDataStream

final class NetworkDataStream {
  typealias StreamResult = Result<Response, Error>
  typealias StreamCompletion = (_ event: NetworkDataStream.ResponseEvent) -> ()

  enum State {
    case initialised
    case resumed
    case suspended
    case cancelled
    case finished
  }

  struct Response {
    let response: HTTPURLResponse?
    let data: Data?
  }

  enum ResponseEvent {
    case stream(StreamResult)
    case complete(Completion)
    case response(HTTPURLResponse?)
  }

  struct Completion {
    let response: HTTPURLResponse?
    let error: Error?
  }

  private var streamCallback: StreamCompletion?

  /// The serial queue for all internal async actions.
  private let underlyingQueue: DispatchQueue
  private let id: UUID

  private var state: State

  var isCancelled: Bool {
    state == .cancelled
  }

  /// the underlying task of the network request
  var task: URLSessionTask?

  var urlResponse: HTTPURLResponse? {
    task?.response as? HTTPURLResponse
  }

  init(id: UUID, underlyingQueue: DispatchQueue) {
    self.id = id
    self.underlyingQueue = underlyingQueue
    self.state = .initialised
  }

  func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
    let task = session.dataTask(with: request)
    self.task = task
    return task
  }

  @discardableResult
  func responseStream(completion: @escaping StreamCompletion) -> Self {
    streamCallback = completion
    return self
  }

  @discardableResult
  func resume() -> Self {
    guard state.canBecome(.resumed) else { return self }
    state = .resumed
    task?.resume()
    return self
  }

  func cancel() {
    guard state.canBecome(.cancelled) else { return }
    state = .cancelled
    streamCallback = nil
    task?.cancel()
    task = nil
  }

  func suspend() {
    guard state.canBecome(.suspended) else { return }
    state = .suspended
    task?.suspend()
  }

  // MARK: Internal

  func didReceive(response: HTTPURLResponse?) {
    underlyingQueue.async { [weak self] in
      guard let self = self else { return }
      guard let streamCallback = streamCallback else { return }
      streamCallback(.response(response))
    }
  }

  func didReceive(data: Data, response: HTTPURLResponse?) {
    underlyingQueue.async { [weak self] in
      guard let self = self else { return }
      guard let streamCallback = streamCallback else { return }
      let streamResponse = Response(response: response, data: data)
      streamCallback(.stream(.success(streamResponse)))
    }
  }

  func didComplete(with error: Error?, response: HTTPURLResponse?) {
    underlyingQueue.async { [weak self] in
      guard let self = self else { return }
      guard let stream = streamCallback else { return }
      if let error = error {
        stream(.stream(.failure(error)))
      } else {
        let completion = Completion(response: response, error: error)
        stream(.complete(completion))
      }
    }
  }
}

// MARK: Equatable

extension NetworkDataStream: Equatable {
  static func == (lhs: NetworkDataStream, rhs: NetworkDataStream) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: Hashable

extension NetworkDataStream: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension NetworkDataStream.State {
  func canBecome(_ state: NetworkDataStream.State) -> Bool {
    switch (self, state) {
    case (.initialised, _):
      return true
    case (_, .initialised),
         (.cancelled, _),
         (.finished, _):
      return false
    case (.resumed, .cancelled),
         (.resumed, .suspended),
         (.suspended, .cancelled),
         (.suspended, .resumed):
      return true
    case (.resumed, .resumed),
         (.suspended, .suspended):
      return false
    case (_, .finished):
      return true
    }
  }
}
