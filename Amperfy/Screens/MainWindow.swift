import UIKit

class MainWindow: UIWindow {
    
    public lazy var appDelegate: AppDelegate = {
        return (UIApplication.shared.delegate as! AppDelegate)
    }()
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard appDelegate.persistentStorage.isLibrarySynced else {
            super.pressesBegan(presses, with: event)
            return
        }
        
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else { continue }
            
            // check that active responder is not an UIControl: no UISearchBarTextField or UITextField
            // only then react to input from keyboard
            let isResponderUIControl = press.responder is UIControl
            guard !isResponderUIControl else { continue }
            if key.charactersIgnoringModifiers == " " {
                appDelegate.player.togglePlayPause()
                didHandleEvent = true
            }
        }
        
        if didHandleEvent == false {
            // Didn't handle this key press, so pass the event to the next responder.
            super.pressesBegan(presses, with: event)
        }
    }
}
