//
//  BehaviourStylable.swift
//  Amperfy
//
//  Created by David Klopp on 15.08.24.
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

import Foundation
import SwiftUI
import UIKit

extension UIBehavioralStyle {
  #if targetEnvironment(macCatalyst)
    static var defaultStyle: UIBehavioralStyle { .mac }
  #else
    static var defaultStyle: UIBehavioralStyle { .pad }
  #endif
}

// MARK: - BehavioralStylable

@MainActor
protocol BehavioralStylable {
  var behavioralStyle: UIBehavioralStyle { get }
  var preferredBehavioralStyle: UIBehavioralStyle { get set }
}

extension BehavioralStylable where Self: View {
  var behavioralStyle: UIBehavioralStyle { preferredBehavioralStyle }

  func preferredBehavioralStyle(_ style: UIBehavioralStyle) -> some View {
    var copy = self
    copy.preferredBehavioralStyle = style
    return copy
  }
}
