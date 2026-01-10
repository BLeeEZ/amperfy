//
//  PlayPausePlaybackIntent.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import AppIntents
import Foundation
import UIKit

// MARK: - PlayPausePlaybackIntent

struct PlayPausePlaybackIntent: AppIntent {
  static let intentClassName = "PlayPausePlaybackIntent"
  static let title: LocalizedStringResource = "Play/Pause Playback"
  static let description = IntentDescription("Play/Pause playback.")

  @Parameter(
    title: "Play/Pause",
    default: .toggle
  )
  var playPauseMode: PlayPausePlaybackAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$playPauseMode) playback") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    switch playPauseMode {
    case .play:
      appDelegate.player.play()
    case .pause:
      appDelegate.player.pause()
    case .toggle:
      appDelegate.player.togglePlayPause()
    }
    return .result()
  }
}
