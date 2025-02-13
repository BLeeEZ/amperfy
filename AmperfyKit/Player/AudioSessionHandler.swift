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

@MainActor
class AudioSessionHandler {
  var musicPlayer: AudioPlayer?
  var eventLogger: EventLogger?

  func configureObserverForAudioSessionInterruption() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
  }

  @objc
  private func handleAudioSessionInterruption(notification: NSNotification) {
    guard let interruptionTypeRaw: NSNumber = notification
      .userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber,
      let interruptionType = AVAudioSession
      .InterruptionType(rawValue: interruptionTypeRaw.uintValue) else {
      os_log(.error, "Audio Session: Audio interruption type invalid")
      return
    }

    switch interruptionType {
    case AVAudioSession.InterruptionType.began:
      // Audio has stopped, already inactive
      // Change state of UI, etc., to reflect non-playing state
      os_log(.info, "Audio Session: Audio interruption began")
      musicPlayer?.pause()
    case AVAudioSession.InterruptionType.ended:
      // Make session active
      // Update user interface
      // AVAudioSessionInterruptionOptionShouldResume option
      os_log(.info, "Audio Session: Audio interruption ended")
      if let interruptionOptionRaw: NSNumber = notification
        .userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber {
        let interruptionOption = AVAudioSession
          .InterruptionOptions(rawValue: interruptionOptionRaw.uintValue)
        if interruptionOption == AVAudioSession.InterruptionOptions.shouldResume {
          // Here you should continue playback
          os_log(.info, "Audio Session: Audio interruption ended -> Resume playing")
          musicPlayer?.play()
        }
      }
    default: break
    }
  }

  @objc
  private func handleRouteChange(notification: NSNotification) {
    os_log(.info, "Audio Session: route changed")
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    switch reason {
    case .newDeviceAvailable:
      let session = AVAudioSession.sharedInstance()
      for output in session.currentRoute.outputs where
        output.portType == AVAudioSession.Port.headphones ||
        output.portType == AVAudioSession.Port.bluetoothA2DP {
        os_log(.info, "Audio Session: headphones connected")
        Task { @MainActor in
          self.musicPlayer?.play()
        }
        break
      }
    case .oldDeviceUnavailable:
      if let previousRoute =
        userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
        for output in previousRoute.outputs where
          output.portType == AVAudioSession.Port.headphones ||
          output.portType == AVAudioSession.Port.bluetoothA2DP {
          os_log(.info, "Audio Session: headphones disconnected")
          Task { @MainActor in
            self.musicPlayer?.pause()
          }
          break
        }
      }
    default: break
    }
  }

  func configureBackgroundPlayback() {
    do {
      try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      eventLogger?.report(topic: "Audio Session", error: error)
    }
  }
}
