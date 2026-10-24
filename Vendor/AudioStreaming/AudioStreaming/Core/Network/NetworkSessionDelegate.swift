//
//  Created by Dimitrios Chatzieleftheriou on 26/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation
import OSLog

final class NetworkSessionDelegate: NSObject, URLSessionDataDelegate {
  weak var taskProvider: StreamTaskProvider?

  func stream(for task: URLSessionTask) -> NetworkDataStream? {
    guard let taskProvider = taskProvider else {
      // This can happen during session cleanup when callbacks are still in flight
      Logger.debug("taskProvider is nil - likely during session cleanup", category: .generic)
      return nil
    }
    return taskProvider.dataStream(for: task)
  }

  func urlSession(
    _: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    guard let stream = stream(for: dataTask) else {
      return
    }
    stream.didReceive(
      data: data,
      response: dataTask.response as? HTTPURLResponse
    )
  }

  func urlSession(
    _: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let stream = stream(for: task) else {
      return
    }
    stream.didComplete(with: error, response: task.response as? HTTPURLResponse)
  }

  func urlSession(
    _: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> ()
  ) {
    guard let stream = stream(for: dataTask) else {
      return
    }
    stream.didReceive(response: response as? HTTPURLResponse)
    completionHandler(.allow)
  }
}
