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

import OSLog
import SystemConfiguration
import Alamofire

public class NetworkMonitor {
    
    private var reachabilityManager = Alamofire.NetworkReachabilityManager()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let log = OSLog(subsystem: "Amperfy", category: "NetworkMonitor")
    private let accessSemaphore = DispatchSemaphore(value: 1)
    private var isCellularConnected = false
    
    public var isConnectedToNetwork: Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
    }
    
    public var isCellular: Bool {
        self.accessSemaphore.wait()
        defer { self.accessSemaphore.signal() }
        chechForRunningReachabilty()
        return self.isCellularConnected
    }
    
    public var isWifiOrEthernet: Bool {
        self.accessSemaphore.wait()
        defer { self.accessSemaphore.signal() }
        chechForRunningReachabilty()
        return !isCellularConnected
    }
    
    private func chechForRunningReachabilty() {
        if reachabilityManager == nil {
            reachabilityManager = Alamofire.NetworkReachabilityManager()
            start()
        }
    }
        
    public func start() {
        self.accessSemaphore.wait()
        if let reachabilityManager = reachabilityManager {
            self.accessSemaphore.signal()
            
            os_log("Start listening for network type changes", log: self.log, type: .info)
            reachabilityManager.startListening()  { status in
                self.accessSemaphore.wait()
                defer { self.accessSemaphore.signal() }
                
                switch status {
                case .notReachable:
                    os_log("Disconnected: The network is not reachable", log: self.log, type: .info)
                case .unknown:
                    os_log("Disconnected: It is unknown whether the network is reachable", log: self.log, type: .info)
                case .reachable(.ethernetOrWiFi):
                    self.isCellularConnected = false
                    os_log("Connected: The network is reachable over the WiFi connection", log: self.log, type: .info)
                case .reachable(.cellular):
                    self.isCellularConnected = true
                    os_log("Connected: The network is reachable over the WWAN connection", log: self.log, type: .info)
                }
            }
        } else {
            self.accessSemaphore.signal()
        }

    }
    

    
}
