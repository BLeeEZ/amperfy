//
//  MacWindowHelper.swift
//  Amperfy
//
//  Created by Mike Liddle on 04.03.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

#if targetEnvironment(macCatalyst)

  import ObjectiveC
  import UIKit

  // NSWindow.Level.floating = 3, NSWindow.Level.normal = 0 https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct
  private let nsWindowLevelFloating = 3
  private let nsWindowLevelNormal = 0

  enum MacWindowHelper {
    static func setAlwaysOnTop(
      _ alwaysOnTop: Bool,
      sceneTitle: String
    ) {
      let level = alwaysOnTop ? nsWindowLevelFloating : nsWindowLevelNormal

      guard let appClass = NSClassFromString("NSApplication")
        as? NSObject.Type
      else { return }

      let sharedApp = appClass
        .perform(NSSelectorFromString("sharedApplication"))?
        .takeUnretainedValue()

      guard let app = sharedApp,
            let nsWindows = (app as AnyObject)
            .perform(NSSelectorFromString("windows"))?
            .takeUnretainedValue() as? [AnyObject]
      else { return }

      let setLevelSel = NSSelectorFromString("setLevel:")

      for nsWindow in nsWindows {
        guard let title = nsWindow
          .perform(NSSelectorFromString("title"))?
          .takeUnretainedValue() as? String,
          title == sceneTitle
        else { continue }

        guard let method = class_getInstanceMethod(
          type(of: nsWindow),
          setLevelSel
        ) else { continue }

        typealias SetLevelFunc = @convention(c)
          (AnyObject, Selector, Int) -> ()
        let impl = method_getImplementation(method)
        let setLevel = unsafeBitCast(impl, to: SetLevelFunc.self)
        setLevel(nsWindow, setLevelSel, level)
      }
    }
  }

#endif
