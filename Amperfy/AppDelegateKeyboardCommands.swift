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

import OSLog
import UIKit

// MARK: - KeyboardCommand

struct KeyboardCommand: Equatable {
  let input: String
  let modifierFlags: UIKeyModifierFlags
}

// MARK: - KeyboardCommands

@MainActor
enum KeyboardCommands: CaseIterable {
  case togglePausePlay
  case previous
  case next
  case search
  case repeatPlayback
  case shuffle
  case musicPodcastMode
  case openClosePlayer

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
    case .openClosePlayer:
      return "Open/Close Player"
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
    case .openClosePlayer:
      return KeyboardCommand(input: "p", modifierFlags: [])
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
    cmd.title = name
    return cmd
  }
}

extension AppDelegate {
  open override var canBecomeFirstResponder: Bool {
    true
  }

  open override var keyCommands: [UIKeyCommand]? {
    KeyboardCommands.allCases.map { cmd in
      cmd.asUIKeyCommand(action: #selector(handleKeyCommand(sender:)))
    }
  }

  @objc
  fileprivate func handleKeyCommand(sender: UIKeyCommand) {
    guard let senderInput = sender.input,
          storage.settings.app.isLibrarySynced
    else { return }
    let cmd = KeyboardCommand(input: senderInput, modifierFlags: sender.modifierFlags)
    guard let cmdEnum = KeyboardCommands.isA(cmd: cmd) else { return }

    os_log("KeyboardCommand: %s", log: self.log, type: .info, cmdEnum.name)

    switch cmdEnum {
    case .togglePausePlay:
      player.togglePlayPause()
    case .previous:
      player.playPreviousOrReplay()
    case .next:
      player.playNext()
    case .search:
      displaySearchTab()
    case .repeatPlayback:
      player.setRepeatMode(player.repeatMode.nextMode)
    case .shuffle:
      player.toggleShuffle()
    case .musicPodcastMode:
      player.setPlayerMode(player.playerMode.nextMode)
    case .openClosePlayer:
      visualizePopupPlayer(direction: .toggle, animated: true)
    }
  }
}

extension KeyCommandTableViewController {
  override var keyCommands: [UIKeyCommand]? {
    [
      // select
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(selectKeyTapped)), // enter
      UIKeyCommand(input: "l", modifierFlags: [], action: #selector(selectKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputRightArrow,
        modifierFlags: .shift,
        action: #selector(selectKeyTapped)
      ),
      // remove selection
      UIKeyCommand(
        input: UIKeyCommand.inputEscape,
        modifierFlags: .shift,
        action: #selector(escapeKeyTapped)
      ),
      // navigation
      UIKeyCommand(input: "h", modifierFlags: [], action: #selector(goBackKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputLeftArrow,
        modifierFlags: .shift,
        action: #selector(goBackKeyTapped)
      ),
      UIKeyCommand(input: "k", modifierFlags: [], action: #selector(previousKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputUpArrow,
        modifierFlags: .shift,
        action: #selector(previousKeyTapped)
      ),
      UIKeyCommand(input: "j", modifierFlags: [], action: #selector(nextKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputDownArrow,
        modifierFlags: .shift,
        action: #selector(nextKeyTapped)
      ),
    ]
  }

  override var canBecomeFirstResponder: Bool {
    true
  }

  @objc
  func goBackKeyTapped() {
    // if the navigation stack is empty and iPad -> go to sidebar
    if let splitViewController,
       let navigationController {
      if !splitViewController.isCollapsed {
        if navigationController.viewControllers.count == 1 {
          splitViewController.show(.primary)
          splitViewController.viewController(for: .primary)?.becomeFirstResponder()
        }
      }
    }
    navigationController?.popViewController(animated: true)
  }

  @objc
  func escapeKeyTapped() {
    tableViewKeyCommandsController.removeFocus()
  }

  @objc
  func selectKeyTapped() {
    tableViewKeyCommandsController.interactWithFocus()
  }

  @objc
  func nextKeyTapped() {
    tableViewKeyCommandsController.moveFocusToNext()
  }

  @objc
  func previousKeyTapped() {
    tableViewKeyCommandsController.moveFocusToPrevious()
  }
}

extension KeyCommandCollectionViewController {
  open override var keyCommands: [UIKeyCommand]? {
    [
      // select
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(selectKeyTapped)), // enter
      UIKeyCommand(input: "l", modifierFlags: [], action: #selector(selectKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputRightArrow,
        modifierFlags: .shift,
        action: #selector(selectKeyTapped)
      ),
      // remove selection
      UIKeyCommand(
        input: UIKeyCommand.inputEscape,
        modifierFlags: .shift,
        action: #selector(escapeKeyTapped)
      ),
      // navigation
      UIKeyCommand(input: "h", modifierFlags: [], action: #selector(goBackKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputLeftArrow,
        modifierFlags: .shift,
        action: #selector(goBackKeyTapped)
      ),
      UIKeyCommand(input: "k", modifierFlags: [], action: #selector(previousKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputUpArrow,
        modifierFlags: .shift,
        action: #selector(previousKeyTapped)
      ),
      UIKeyCommand(input: "j", modifierFlags: [], action: #selector(nextKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputDownArrow,
        modifierFlags: .shift,
        action: #selector(nextKeyTapped)
      ),
    ]
  }

  open override var canBecomeFirstResponder: Bool {
    true
  }

  @objc
  func goBackKeyTapped() {
    navigationController?.popViewController(animated: true)
  }

  @objc
  func escapeKeyTapped() {
    collectionViewKeyCommandsController.removeFocus()
  }

  @objc
  func selectKeyTapped() {
    collectionViewKeyCommandsController.interactWithFocus()

    if let splitViewController,
       !splitViewController.isCollapsed {
      if splitViewController.displayMode == .oneOverSecondary {
        splitViewController.hide(.primary)
      }
      splitViewController.viewController(for: .secondary)?.becomeFirstResponder()
    }
  }

  @objc
  func nextKeyTapped() {
    collectionViewKeyCommandsController.moveFocusToNext()
  }

  @objc
  func previousKeyTapped() {
    collectionViewKeyCommandsController.moveFocusToPrevious()
  }
}

extension BasicTableViewController {
  override var keyCommands: [UIKeyCommand]? {
    var commands = super.keyCommands ?? [UIKeyCommand]()
    commands.append(
      contentsOf:
      [
        UIKeyCommand(input: "f", modifierFlags: [], action: #selector(searchKeyTapped)),
      ]
    )
    return commands
  }

  override var canBecomeFirstResponder: Bool {
    true
  }

  @objc
  func searchKeyTapped() {
    searchController.searchBar.becomeFirstResponder()
  }
}

extension PopupPlayerVC {
  override var keyCommands: [UIKeyCommand]? {
    [
      // select
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(selectKeyTapped)), // enter
      UIKeyCommand(input: "l", modifierFlags: [], action: #selector(selectKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputRightArrow,
        modifierFlags: .shift,
        action: #selector(selectKeyTapped)
      ),
      // remove selection
      UIKeyCommand(
        input: UIKeyCommand.inputEscape,
        modifierFlags: .shift,
        action: #selector(escapeKeyTapped)
      ),
      // navigation
      UIKeyCommand(input: "h", modifierFlags: [], action: #selector(goBackKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputLeftArrow,
        modifierFlags: .shift,
        action: #selector(goBackKeyTapped)
      ),
      UIKeyCommand(input: "k", modifierFlags: [], action: #selector(previousKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputUpArrow,
        modifierFlags: .shift,
        action: #selector(previousKeyTapped)
      ),
      UIKeyCommand(input: "j", modifierFlags: [], action: #selector(nextKeyTapped)),
      UIKeyCommand(
        input: UIKeyCommand.inputDownArrow,
        modifierFlags: .shift,
        action: #selector(nextKeyTapped)
      ),
    ]
  }

  override var canBecomeFirstResponder: Bool {
    true
  }

  @objc
  func goBackKeyTapped() {
    navigationController?.popViewController(animated: true)
  }

  @objc
  func escapeKeyTapped() {
    tableViewKeyCommandsController.removeFocus()
  }

  @objc
  func selectKeyTapped() {
    tableViewKeyCommandsController.interactWithFocus()
  }

  @objc
  func nextKeyTapped() {
    tableViewKeyCommandsController.moveFocusToNext()
  }

  @objc
  func previousKeyTapped() {
    tableViewKeyCommandsController.moveFocusToPrevious()
  }
}

extension TabBarVC {
  override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(input: "1", modifierFlags: [], action: #selector(moveToTab1)),
      UIKeyCommand(input: "2", modifierFlags: [], action: #selector(moveToTab2)),
      UIKeyCommand(input: "3", modifierFlags: [], action: #selector(moveToTab3)),
    ]
  }

  override var canBecomeFirstResponder: Bool {
    true
  }

  @objc
  func moveToTab1() {
    moveToIndex(index: 0)
  }

  @objc
  func moveToTab2() {
    moveToIndex(index: 1)
  }

  @objc
  func moveToTab3() {
    moveToIndex(index: 2)
  }

  func moveToIndex(index: Int) {
    if (viewControllers?.count ?? 0) > index {
      selectedIndex = index
    }
  }
}
