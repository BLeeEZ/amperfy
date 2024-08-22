//
//  Refreshable.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation

#if targetEnvironment(macCatalyst)

protocol Refreshable {
    func reload()
}

#endif
