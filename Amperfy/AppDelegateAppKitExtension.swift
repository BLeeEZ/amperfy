//
//  AppDelegateAppKitExtension.swift
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

import Foundation
import UIKit
import CoreGraphics

#if targetEnvironment(macCatalyst)
typealias AppKitController = NSObject

extension AppKitController {
    @objc public func updateControlAccentColor(_ color: CGColor) {}
    @objc public func installControlAccentColorHook() {}

    @objc public func _catalyst_setupWindow(_ sender:Any) {}
    @objc public func configurePreferencesWindowForSceneIdentifier(_ sceneIdentifier: String) {}
}

extension AppDelegate {
    static var appKitController: NSObject?

    class func installAppKitColorHooks() {
        appKitController?.perform(#selector(installControlAccentColorHook))
    }

    class func updateAppKitControlColor() {
        let accentColor = UIView.appearance().tintColor.cgColor
        appKitController?.perform(#selector(updateControlAccentColor(_:)), with: accentColor)
    }

    class func configurePreferenceWindow(persistentIdentifier: String) {
        appKitController?.perform(#selector(configurePreferencesWindowForSceneIdentifier(_:)), with: persistentIdentifier)
    }

    class func loadAppKitIntegrationFramework() {

        if let frameworksPath = Bundle.main.privateFrameworksPath {
            let bundlePath = "\(frameworksPath)/AppKitIntegration.framework"
            do {
                try Bundle(path: bundlePath)?.loadAndReturnError()

                let bundle = Bundle(path: bundlePath)!
                NSLog("[APPKIT BUNDLE] Loaded Successfully")

                if let appKitControllerClass = bundle.classNamed("AppKitIntegration.AppKitController") as? NSObject.Type {
                    appKitController = appKitControllerClass.init()

                    NotificationCenter.default.addObserver(appKitController as Any, selector: #selector(_catalyst_setupWindow(_:)), name: NSNotification.Name("UISBHSDidCreateWindowForSceneNotification"), object: nil)
                }
            }
            catch {
                NSLog("[APPKIT BUNDLE] Error loading: \(error)")
            }
        }
    }
}
#endif
