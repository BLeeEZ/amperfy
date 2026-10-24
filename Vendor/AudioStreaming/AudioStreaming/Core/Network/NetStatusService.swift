//
//  Created by Dimitrios Chatzieleftheriou on 18/09/2020.
//  Copyright © 2020 decimal. All rights reserved.
//

import Foundation
import Network

// MARK: - NetConnectionType

enum NetConnectionType: Equatable {
  case cellular(connected: Bool)
  case wifi(connected: Bool)
  case other(connected: Bool)
  case undetermined

  var isConnected: Bool {
    switch self {
    case let .cellular(connected),
         let .other(connected),
         let .wifi(connected):
      return connected
    default:
      return false
    }
  }
}

// MARK: - NetStatusProvider

protocol NetStatusProvider {
  var isConnected: Bool { get }
  var connectionType: NetConnectionType { get }

  func start(connectionChange: @escaping (NetConnectionType) -> ())
  func stop()
}

// MARK: - NetStatusService

final class NetStatusService: NetStatusProvider {
  var isConnected: Bool {
    network.currentPath.status == .satisfied
  }

  var connectionType: NetConnectionType {
    network.currentPath.toNetConnectionType()
  }

  private let network: NWPathMonitor

  private let monitorQueue: DispatchQueue

  init(network: NWPathMonitor) {
    self.network = network
    self.monitorQueue = DispatchQueue(label: "net.path.queue", qos: .utility)
  }

  deinit {
    network.cancel()
  }

  /// Starts the monitoring of connection changes
  ///
  /// - parameter connectionChange: A callback block to listen to changes of the network type, this skips duplicates.
  /// - Note:  The callback will be executed on the main thread.
  func start(connectionChange: @escaping (NetConnectionType) -> ()) {
    network.pathUpdateHandler = { path in
      let connectionType = path.toNetConnectionType()
      connectionChange(connectionType)
    }
    startIfNeeded()
  }

  func stop() {
    network.cancel()
  }

  func startIfNeeded() {
    guard network.queue == nil else { return }
    network.start(queue: monitorQueue)
  }
}

extension NWPath {
  func toNetConnectionType() -> NetConnectionType {
    let isCellular = usesInterfaceType(.cellular)
    let isWifi = usesInterfaceType(.wifi)
    let isOther = usesInterfaceType(.loopback)
      || usesInterfaceType(.other)
      || usesInterfaceType(.wiredEthernet)
    let isConnected = status == .satisfied

    if isCellular {
      return .cellular(connected: isConnected)
    } else if isWifi {
      return .wifi(connected: isConnected)
    } else if isOther {
      return .other(connected: isConnected)
    }

    return .undetermined
  }
}
