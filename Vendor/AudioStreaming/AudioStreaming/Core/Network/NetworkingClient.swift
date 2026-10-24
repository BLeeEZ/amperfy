//
//  Created by Dimitrios Chatzieleftheriou on 26/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - DataStreamError

enum DataStreamError: Error {
  case unknown
  case sessionDeinit
}

// MARK: - NetworkError

public enum NetworkError: Error, Equatable {
  case failure(Error)
  case serverError
  case missingData
  public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
    switch (lhs, rhs) {
    case (.failure, failure):
      return true
    case (.serverError, .serverError):
      return true
    case (.missingData, .missingData):
      return true
    default:
      return false
    }
  }
}

// MARK: - StreamTaskProvider

protocol StreamTaskProvider: AnyObject {
  func dataStream(for request: URLSessionTask) -> NetworkDataStream?
}

extension URLSessionConfiguration {
  static var networkingConfiguration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.default
    configuration.networkServiceType = .avStreaming
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.shouldUseExtendedBackgroundIdleMode = true
    return configuration
  }
}

// MARK: - NetworkingClient

final class NetworkingClient {
  let session: URLSession
  weak var delegate: NetworkSessionDelegate?
  let networkQueue: DispatchQueue

  var tasksLock = UnfairLock()
  var tasks = BiMap<URLSessionTask, NetworkDataStream>()

  init(
    configuration: URLSessionConfiguration = .networkingConfiguration,
    delegate: NetworkSessionDelegate = NetworkSessionDelegate(),
    networkQueue: DispatchQueue = DispatchQueue(label: "audio.streaming.session.network.queue")
  ) {
    let delegateQueue = operationQueue(underlyingQueue: networkQueue)
    let session = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: delegateQueue
    )
    self.session = session
    self.delegate = delegate
    self.networkQueue = networkQueue
    delegate.taskProvider = self
  }

  deinit {
    session.finishTasksAndInvalidate()
  }

  /// Creates a data stream for the given `URLRequest`
  /// - parameter request: A `URLRequest` to be used for the data stream
  func stream(request: URLRequest) -> NetworkDataStream {
    let stream = NetworkDataStream(id: UUID(), underlyingQueue: networkQueue)
    setupRequest(stream, request: request)
    return stream
  }

  func remove(task: NetworkDataStream) {
    tasksLock.withLock {
      if !tasks.isEmpty {
        tasks[task] = nil
      }
    }
  }

  @discardableResult
  func task(
    request: URLRequest,
    completion: @escaping (Result<Data, Error>) -> ()
  )
    -> URLSessionDataTask {
    let task = session.dataTask(with: request) { data, _, error in
      if let error {
        completion(Result<Data, Error>.failure(error))
        return
      }
      if let data {
        completion(Result<Data, Error>.success(data))
      }
    }
    task.resume()
    return task
  }

  // MARK: Private

  /// Schedules the given `NetworkDataStream` to be performed immediately
  /// - parameter stream: The `NetworkDataStream` object to be performed
  /// - parameter request: The `URLRequest` for the `stream`
  private func setupRequest(_ stream: NetworkDataStream, request: URLRequest) {
    tasksLock.lock(); defer { tasksLock.unlock() }
    guard !stream.isCancelled else { return }
    let task = stream.task(for: request, using: session)
    tasks[stream] = task
  }
}

// MARK: StreamTaskProvider

extension NetworkingClient: StreamTaskProvider {
  func dataStream(for request: URLSessionTask) -> NetworkDataStream? {
    tasksLock.withLock {
      tasks[request] ?? nil
    }
  }

  func sessionTask(for stream: NetworkDataStream) -> URLSessionTask? {
    tasksLock.withLock {
      tasks[stream] ?? nil
    }
  }
}

// MARK: Helper

private func operationQueue(underlyingQueue: DispatchQueue) -> OperationQueue {
  let delegateQueue = OperationQueue()
  delegateQueue.qualityOfService = .default
  delegateQueue.maxConcurrentOperationCount = 1
  delegateQueue.underlyingQueue = underlyingQueue
  delegateQueue.name = "com.decimal.session.delegate.queue"
  return delegateQueue
}
