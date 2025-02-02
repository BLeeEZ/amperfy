//
//  NotificationDetailVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 04.03.24.
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
import AmperfyKit
import MarqueeLabel

class NotificationDetailVC: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    var topic = ""
    var message = ""
    var logType = LogEntryType.info
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.setBackgroundBlur(style: .prominent)
        
        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .large()
            ]
            if traitCollection.horizontalSizeClass == .compact {
                presentationController.detents.append(.medium())
            }
        }
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        refresh()
    }

    func display(title: String, message: String, type: LogEntryType) {
        self.topic = title
        self.message = message
    }

    func refresh() {
        titleLabel.text = self.topic
        descriptionTextView.text = self.message
    }
    
    @IBAction func pressedClose(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
