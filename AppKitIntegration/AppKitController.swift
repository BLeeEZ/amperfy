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

	@objc public func _catalyst_setupWindow(_ note: Notification) {

		guard let preferencesSceneIdentifier = preferencesSceneIdentifier else { return }
		
		if let userInfo = note.userInfo, let sceneIdentifier = userInfo["SceneIdentifier"] as? String {
			if sceneIdentifier.hasSuffix(preferencesSceneIdentifier) {
				guard let appDelegate = NSApp.delegate as? NSObject else { return }
				
				if appDelegate.responds(to: #selector(hostWindowForSceneIdentifier(_:))) {
					guard let hostWindow = appDelegate.hostWindowForSceneIdentifier(sceneIdentifier) else { return }
					
					hostWindow.collectionBehavior = [.fullScreenAuxiliary]
                    hostWindow.styleMask = [.closable, .titled, .fullSizeContentView]
					hostWindow.isRestorable = false
				}
			}
		}
	}
	
	@objc public func configurePreferencesWindowForSceneIdentifier(_ sceneIdentifier: String) {
		preferencesSceneIdentifier = sceneIdentifier
	}
}
