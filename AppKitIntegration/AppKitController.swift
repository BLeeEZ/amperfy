/*
2021 Steven Troughton-Smith (@stroughtonsmith)
Provided as sample code to do with as you wish.
No license or attribution required.
*/

import AppKit

extension NSObject {
	@objc func hostWindowForSceneIdentifier(_ identifier:String) -> NSWindow? {
		return nil
	}
}

class AppKitController: NSObject {
	
	var preferencesSceneIdentifier: String?

    @objc static var controlAccentAppColor: NSColor? = .clear

    @objc public func updateControlAccentColor(_ color: CGColor) {
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

    @objc public func installControlAccentColorHook() {
        guard let swizzledMethod = class_getClassMethod(AppKitController.self, #selector(getter: AppKitController.controlAccentAppColor)) else { return }

        // Style NSToolbarItem
        guard let method = class_getClassMethod(NSColor.self, #selector(getter: NSColor.controlAccentColor)) else { return }
        method_exchangeImplementations(method, swizzledMethod)
    }

	@objc public func _catalyst_setupWindow(_ note: Notification) {

		guard let preferencesSceneIdentifier = preferencesSceneIdentifier else { return }
		
		if let userInfo = note.userInfo, let sceneIdentifier = userInfo["SceneIdentifier"] as? String {
			if sceneIdentifier.hasSuffix(preferencesSceneIdentifier) {
				guard let appDelegate = NSApp.delegate as? NSObject else { return }
				
				if appDelegate.responds(to: #selector(hostWindowForSceneIdentifier(_:))) {
					guard let hostWindow = appDelegate.hostWindowForSceneIdentifier(sceneIdentifier) else { return }

					hostWindow.collectionBehavior = [.fullScreenAuxiliary]
                    hostWindow.styleMask = [.closable, .titled]
					hostWindow.isRestorable = false
				}
			}
		}
	}
	
	@objc public func configurePreferencesWindowForSceneIdentifier(_ sceneIdentifier: String) {
		preferencesSceneIdentifier = sceneIdentifier
	}
}
