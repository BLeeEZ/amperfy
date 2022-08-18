//
//  AudioSessionHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 23.11.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import MediaPlayer
import os.log

class AudioSessionHandler {
    
    private let musicPlayer: AudioPlayer

    init(musicPlayer: AudioPlayer) {
        self.musicPlayer = musicPlayer
    }
    
    func configureObserverForAudioSessionInterruption(audioSession: AVAudioSession) {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: audioSession)
    }
    
    @objc private func handleAudioSessionInterruption(notification: NSNotification) {
        guard let interruptionTypeRaw: NSNumber = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRaw.uintValue) else {
                os_log(.error, "Audio interruption type invalid")
                return
        }
        
        switch (interruptionType) {
        case AVAudioSession.InterruptionType.began:
            // Audio has stopped, already inactive
            // Change state of UI, etc., to reflect non-playing state
            os_log(.info, "Audio interruption began")
            musicPlayer.pause()
        case AVAudioSession.InterruptionType.ended:
            // Make session active
            // Update user interface
            // AVAudioSessionInterruptionOptionShouldResume option
            os_log(.info, "Audio interruption ended")
            if let interruptionOptionRaw: NSNumber = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber {
                let interruptionOption = AVAudioSession.InterruptionOptions(rawValue: interruptionOptionRaw.uintValue)
                if interruptionOption == AVAudioSession.InterruptionOptions.shouldResume {
                    // Here you should continue playback
                    os_log(.info, "Audio interruption ended -> Resume playing")
                    musicPlayer.play()
                }
            }
        default: break
        }
    }

    func configureBackgroundPlayback(audioSession: AVAudioSession) {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            try audioSession.setActive(true)
        } catch {
            os_log(.error, "Error Player: %s", error.localizedDescription)
        }
    }
    
}
