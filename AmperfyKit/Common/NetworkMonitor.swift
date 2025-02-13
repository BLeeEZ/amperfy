//
//  NetworkMonitor.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 02.04.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Alamofire
import Network
import OSLog
import SystemConfiguration

public typealias ConnectionTypeChangedCallack = @Sendable (_ isWiFiConnected: Bool) async -> ()

// MARK: - NetworkMonitorFacade

public protocol NetworkMonitorFacade {
  @MainActor
  func getConnectionTypeChangedCB() -> ConnectionTypeChangedCallack?
  @MainActor
  func setConnectionTypeChangedCB(newCB: ConnectionTypeChangedCallack?)
  @MainActor
  var isConnectedToNetwork: Bool { get }
  @MainActor
  var isCellular: Bool { get }
  @MainActor
  var isWifiOrEthernet: Bool { get }
}

// MARK: - NetworkMonitor

@MainActor
public class NetworkMonitor: NetworkMonitorFacade {
  public static let shared = NetworkMonitor().start()

  private var reachabilityManager = Alamofire.NetworkReachabilityManager()
  private let queue = DispatchQueue(label: "NetworkMonitor")
  private let log = OSLog(subsystem: "Amperfy", category: "NetworkMonitor")
  private var connectionTypeChangedCB: ConnectionTypeChangedCallack?

  public func getConnectionTypeChangedCB() -> ConnectionTypeChangedCallack? {
    connectionTypeChangedCB
  }

  public func setConnectionTypeChangedCB(newCB: ConnectionTypeChangedCallack?) {
    _setConnectionTypeChangedCB(newCB: newCB)
  }

  private func _setConnectionTypeChangedCB(newCB: ConnectionTypeChangedCallack?) {
    connectionTypeChangedCB = newCB
  }

  private let monitor = NWPathMonitor()
  private var networkPath: NWPath

  init() {
    self.networkPath = monitor.currentPath
  }

  private func updateNetworkPath(newPath: NWPath) async {
    networkPath = newPath

    if networkPath.status != .satisfied {
      os_log("Disconnected: The network is not reachable", log: self.log, type: .info)
    } else if networkPath.usesInterfaceType(.cellular) {
      os_log(
        "Connected: The network is reachable over the Cellular connection",
        log: self.log,
        type: .info
      )
    } else if networkPath.usesInterfaceType(.wifi) {
      os_log(
        "Connected: The network is reachable over the WiFi connection",
        log: self.log,
        type: .info
      )
    } else if networkPath.usesInterfaceType(.wiredEthernet) {
      os_log(
        "Connected: The network is reachable over the Ethernet connection",
        log: self.log,
        type: .info
      )
    } else if networkPath.usesInterfaceType(.other) {
      os_log(
        "Connected: The network is reachable over Other connection",
        log: self.log,
        type: .info
      )
    } else if networkPath.usesInterfaceType(.loopback) {
      os_log(
        "Connected: The network is reachable over Loop Back connection",
        log: self.log,
        type: .info
      )
    }

    await connectionTypeChangedCB?(!isCellular)
  }

  func start() -> NetworkMonitor {
    monitor.pathUpdateHandler = { [self] networkPath in
      Task {
        await updateNetworkPath(newPath: networkPath)
      }
    }
    monitor.start(queue: queue)
    return self
  }

  public var isConnectedToNetwork: Bool {
    let isConneted = networkPath.status == .satisfied
    return isConneted
  }

  public var isCellular: Bool {
    networkPath.usesInterfaceType(.cellular)
  }

  public var isWifiOrEthernet: Bool {
    !isCellular
  }
}
