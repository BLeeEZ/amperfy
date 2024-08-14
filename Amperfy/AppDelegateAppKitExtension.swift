//
//  AppDelegateAppKitExtension.swift
//  Amperfy
//
//  Created by David Klopp on 13.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
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
