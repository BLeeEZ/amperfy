//
//  AppDelegateKeyboardCommands.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.02.24.
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

import UIKit
import OSLog

struct KeyboardCommand: Equatable {
    let input: String
    let modifierFlags: UIKeyModifierFlags
}

enum KeyboardCommands: CaseIterable {
    case togglePausePlay
    case previous
    case next
    case search
    case repeatPlayback
    case shuffle
    case musicPodcastMode
    
    var name: String {
        switch self {
        case .togglePausePlay:
            return "Toggle Play and Pause"
        case .previous:
            return "Play Previous"
        case .next:
            return "Play Next"
        case .search:
            return "Search"
        case .repeatPlayback:
            return "Repeat"
        case .shuffle:
            return "Shuffle"
        case .musicPodcastMode:
            return "Switch between Music and Podcast mode"
        }
    }
    
    var asCommand: KeyboardCommand {
        switch self {
        case .togglePausePlay:
            return KeyboardCommand(input: " ", modifierFlags: [])
        case .previous:
            return KeyboardCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [])
        case .next:
            return KeyboardCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [])
        case .search:
            return KeyboardCommand(input: "f", modifierFlags: [.command])
        case .repeatPlayback:
            return KeyboardCommand(input: "r", modifierFlags: [])
        case .shuffle:
            return KeyboardCommand(input: "s", modifierFlags: [])
        case .musicPodcastMode:
            return KeyboardCommand(input: "m", modifierFlags: [])
        }
    }
    
    static func isA(cmd: KeyboardCommand) -> KeyboardCommands? {
        for cmdEnum in Self.allCases {
            if cmdEnum.asCommand == cmd {
                return cmdEnum
            }
        }
        return nil
    }
    
    func asUIKeyCommand(action: Selector) -> UIKeyCommand {
        let keyCmd = asCommand
        let cmd = UIKeyCommand(input: keyCmd.input, modifierFlags: keyCmd.modifierFlags, action: action)
        cmd.title = self.name
        return cmd
    }
}

extension AppDelegate {

    open override var canBecomeFirstResponder: Bool {
        return true
    }
    
    open override var keyCommands: [UIKeyCommand]? {
        return KeyboardCommands.allCases.map { cmd in
            cmd.asUIKeyCommand(action: #selector(handleKeyCommand(sender:)))
        }
    }
    
    @objc fileprivate func handleKeyCommand(sender: UIKeyCommand) {
        guard let senderInput = sender.input,
              self.storage.isLibrarySynced
        else { return }
        let cmd = KeyboardCommand(input: senderInput, modifierFlags: sender.modifierFlags)
        guard let cmdEnum = KeyboardCommands.isA(cmd: cmd) else { return }
        
        os_log("KeyboardCommand: %s", log: self.log, type: .info, cmdEnum.name)
        
        switch cmdEnum {
        case .togglePausePlay:
            self.player.togglePlayPause()
        case .previous:
            self.player.playPreviousOrReplay()
        case .next:
            self.player.playNext()
        case .search:
            self.displaySearchTab()
        case .repeatPlayback:
            self.player.setRepeatMode(self.player.repeatMode.nextMode)
        case .shuffle:
            self.player.toggleShuffle()
        case .musicPodcastMode:
            self.player.setPlayerMode(self.player.playerMode.nextMode)
        }
    }
    
}

