//
//  MainWindow.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 26.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class MainWindow: UIWindow {
    
    public lazy var appDelegate: AppDelegate = {
        return (UIApplication.shared.delegate as! AppDelegate)
    }()
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard appDelegate.storage.isLibrarySynced else {
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
