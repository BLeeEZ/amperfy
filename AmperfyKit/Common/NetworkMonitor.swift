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

public protocol NetworkMonitorFacade: Sendable {
  var connectionTypeChangedCB: ConnectionTypeChangedCallack? { get set }
  var isConnectedToNetwork: Bool { get }
  var isCellular: Bool { get }
  var isWifiOrEthernet: Bool { get }
}

// MARK: - NetworkMonitor

final public class NetworkMonitor: NetworkMonitorFacade {
  private let queue = DispatchQueue(label: "NetworkMonitor")
  private let log = OSLog(subsystem: "Amperfy", category: "NetworkMonitor")
  private let monitor = NWPathMonitor()
  private let networkPath: Atomic<NWPath>
  private let notificationHandler: EventNotificationHandler
  private let _connectionTypeChangedCB = Atomic<ConnectionTypeChangedCallack?>(wrappedValue: nil)

  init(notificationHandler: EventNotificationHandler) {
    self.networkPath = Atomic<NWPath>(wrappedValue: monitor.currentPath)
    self.notificationHandler = notificationHandler
  }

  public var connectionTypeChangedCB: ConnectionTypeChangedCallack? {
    get { _connectionTypeChangedCB.wrappedValue }
    set { _connectionTypeChangedCB.wrappedValue = newValue }
  }

  private func updateNetworkPath(newPath: NWPath) async {
    let isConnectedBeforeChange = isConnectedToNetwork
    networkPath.wrappedValue = newPath
    let isConnectedAfterChange = isConnectedToNetwork

    if newPath.status != .satisfied {
      os_log("Disconnected: The network is not reachable", log: self.log, type: .info)
    } else if newPath.usesInterfaceType(.cellular) {
      os_log(
        "Connected: The network is reachable over the Cellular connection",
        log: self.log,
        type: .info
      )
    } else if newPath.usesInterfaceType(.wifi) {
      os_log(
        "Connected: The network is reachable over the WiFi connection",
        log: self.log,
        type: .info
      )
    } else if newPath.usesInterfaceType(.wiredEthernet) {
      os_log(
        "Connected: The network is reachable over the Ethernet connection",
        log: self.log,
        type: .info
      )
    } else if newPath.usesInterfaceType(.other) {
      os_log(
        "Connected: The network is reachable over Other connection",
        log: self.log,
        type: .info
      )
    } else if newPath.usesInterfaceType(.loopback) {
      os_log(
        "Connected: The network is reachable over Loop Back connection",
        log: self.log,
        type: .info
      )
    }

    if isConnectedBeforeChange != isConnectedAfterChange {
      await notificationHandler.post(
        name: .networkStatusChanged,
        object: self,
        userInfo: nil
      )
    }
    await connectionTypeChangedCB?(!isCellular)
  }

  func start() {
    monitor.pathUpdateHandler = { [self] networkPath in
      Task {
        await updateNetworkPath(newPath: networkPath)
      }
    }
    monitor.start(queue: queue)
  }

  public var isConnectedToNetwork: Bool {
    let isConneted = networkPath.wrappedValue.status == .satisfied
    return isConneted
  }

  public var isCellular: Bool {
    networkPath.wrappedValue.usesInterfaceType(.cellular)
  }

  public var isWifiOrEthernet: Bool {
    isConnectedToNetwork && !isCellular
  }
}
