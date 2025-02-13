//
//  Haptics.swift
//  Amperfy
//
//  Created by daniele on 08/06/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import AmperfyKit
import AudioToolbox
import Foundation
import UIKit

@MainActor
enum Haptics {
  case error
  case success
  case warning
  case light
  case medium
  case heavy
  @available(iOS 13.0, *)
  case soft
  @available(iOS 13.0, *)
  case rigid
  case selection
  case oldSchool

  public func vibrate(isHapticsEnabled: Bool) {
    guard isHapticsEnabled else { return }
    switch self {
    case .error:
      UINotificationFeedbackGenerator().notificationOccurred(.error)
    case .success:
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .light:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .soft:
      if #available(iOS 13.0, *) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    case .rigid:
      if #available(iOS 13.0, *) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
      }
    case .selection:
      UISelectionFeedbackGenerator().selectionChanged()
    case .oldSchool:
      AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
  }
}
