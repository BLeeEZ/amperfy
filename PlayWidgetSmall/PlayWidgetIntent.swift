//
//  PlayByIdIntent.swift
//  Amperfy
//
//  Created by daniele on 22/06/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import AppIntents
import AmperfyKit

@available(iOS 17.0, *)
struct PlayWidgetIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Toggle Play Status"
    static var description: IntentDescription = IntentDescription("Toggles play/pause for the app widget")
    
    func perform() async throws -> some IntentResult {
        AmperKit.shared.player.togglePlayPause()
        return .result()
    }
}
