//
//  AppKitController.swift
//  Amperfy
//
//  Created by David Klopp on 14.08.24.
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

import AppKit

extension NSObject {
  @objc
  func hostWindowForSceneIdentifier(_ identifier: String) -> NSWindow? {
    nil
  }
}

// MARK: - AppKitController

@MainActor
class AppKitController: NSObject {
  // we currently support:
  // - fullSizeContentView: Bool
  // - miniaturizable: Bool
  // - resizable: Bool
  // - aspectRatio: CGSize
  typealias WindowProperties = [String: Any]

  var utilitySceneIdentifier: [String: WindowProperties] = [:]

  var sceneIdentifierToQualifiedSceneIdentifier: [String: String] = [:]

  @objc
  static var controlAccentAppColor: NSColor? = .clear

  @objc
  public func updateControlAccentColor(_ color: CGColor) {
    AppKitController.controlAccentAppColor = NSColor(cgColor: color)

    // Update the appearance of AppKit controls e.g. the ToolbarItems in the settings window
    let newAppearance = NSAppearance()
    NSApp.appearance = newAppearance

    // Redraw the window
    NSApp.windows.forEach {
      $0.appearance = nil
      $0.appearance = newAppearance
    }
  }

  @objc
  public func installControlAccentColorHook() {
    guard let swizzledMethod = class_getClassMethod(
      AppKitController.self,
      #selector(getter: AppKitController.controlAccentAppColor)
    ) else { return }

    // Style NSToolbarItem
    guard let method = class_getClassMethod(
      NSColor.self,
      #selector(getter: NSColor.controlAccentColor)
    ) else { return }
    method_exchangeImplementations(method, swizzledMethod)
  }

  @objc
  public func _catalyst_setupWindow(_ note: Notification) {
    if let userInfo = note.userInfo,
       let qualifiedSceneIdentifier = userInfo["SceneIdentifier"] as? String {
      let kv = utilitySceneIdentifier.first(where: { qualifiedSceneIdentifier.hasSuffix($0.key) })
      if let kv {
        sceneIdentifierToQualifiedSceneIdentifier[kv.key] = qualifiedSceneIdentifier
        let windowProperties = kv.value
        var styleMask: NSWindow.StyleMask = [.closable, .titled]
        if windowProperties["fullSizeContentView"] as? Bool == true {
          styleMask.insert(.fullSizeContentView)
        }
        if windowProperties["miniaturizable"] as? Bool == true {
          styleMask.insert(.miniaturizable)
        }
        if windowProperties["resizable"] as? Bool == true {
          styleMask.insert(.resizable)
        }

        guard let appDelegate = NSApp.delegate as? NSObject else { return }

        if appDelegate.responds(to: #selector(hostWindowForSceneIdentifier(_:))) {
          guard let hostWindow = appDelegate.hostWindowForSceneIdentifier(qualifiedSceneIdentifier)
          else { return }

          if windowProperties["auxiliary"] as? Bool == true {
            hostWindow.collectionBehavior = [.fullScreenAuxiliary]
            hostWindow.styleMask = styleMask
            hostWindow.isRestorable = false
          }

          if let autosaveName = windowProperties["autosaveName"] as? String {
            hostWindow.setFrameAutosaveName(autosaveName)
          }

          if let ratio = windowProperties["aspectRatio"] as? CGSize {
            hostWindow.aspectRatio = ratio
            hostWindow.setFrame(
              CGRect(origin: hostWindow.frame.origin, size: hostWindow.minSize),
              display: true
            )
          }
        }
      }
    }
  }

  @objc
  public func configureUtilityWindowForSceneIdentifier(
    _ sceneIdentifier: String,
    properties: WindowProperties
  ) {
    utilitySceneIdentifier[sceneIdentifier] = properties
  }

  @objc
  public func saveWindowFrameForSceneIdentifier(
    _ sceneIdentifier: String,
    autosaveName: String
  ) {
    guard let appDelegate = NSApp.delegate as? NSObject,
          let qualifiedSceneIdentifier = sceneIdentifierToQualifiedSceneIdentifier[sceneIdentifier]
    else {
      return
    }

    if appDelegate.responds(to: #selector(hostWindowForSceneIdentifier(_:))) {
      guard let hostWindow = appDelegate.hostWindowForSceneIdentifier(qualifiedSceneIdentifier)
      else { return }
      hostWindow.saveFrame(usingName: autosaveName)
    }
  }
}
