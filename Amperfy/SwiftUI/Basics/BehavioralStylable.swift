//
//  BehaviourStylable.swift
//  Amperfy
//
//  Created by David Klopp on 15.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

extension UIBehavioralStyle {
    #if targetEnvironment(macCatalyst)
    static var defaultStyle: UIBehavioralStyle { .mac }
    #else
    static var defaultStyle: UIBehavioralStyle { .pad }
    #endif
}

protocol BehavioralStylable {
    var behavioralStyle: UIBehavioralStyle { get }
    var preferredBehavioralStyle: UIBehavioralStyle { get set }
}

extension BehavioralStylable where Self: View {
    var behavioralStyle: UIBehavioralStyle { self.preferredBehavioralStyle }

    func preferredBehavioralStyle(_ style:  UIBehavioralStyle) -> some View {
        var copy = self
        copy.preferredBehavioralStyle = style
        return copy
    }
}
