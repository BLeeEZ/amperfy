//
//  LibrarySyncPopupVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 16.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

enum PopupIconAnimation {
    case rotate
    case zoomInZoomOut
    case swing
}

class LibrarySyncPopupVC: UIViewController {
    
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var iconBackgroundLabel: UILabel!
    @IBOutlet weak var titelLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var optionalButton: BasicButton!
    @IBOutlet weak var contentView: UIView!
    
    var appDelegate: AppDelegate!
    var topic = ""
    var message = ""
    var logType = LogEntryType.info
    var onClose: (() -> Void)?
    private var popupColor = UIColor.systemBlue
    private var icon = FontAwesomeIcon.Sync
    private var iconAnimation = PopupIconAnimation.zoomInZoomOut
    private var closeButtonOnPressed: ((Bool) -> Void)?
    private var optionalButtonText: String?
    private var optionalButtonOnPressed: ((Bool) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        titelLabel.text = topic
        infoLabel.text = message
        if let btnText = optionalButtonText {
            optionalButton.setTitle(btnText, for: .normal)
        } else {
            optionalButton.removeFromSuperview()
        }
        iconLabel.layer.cornerRadius = iconLabel.frame.width / 2
        iconLabel.layer.masksToBounds = true
        iconBackgroundLabel.layer.cornerRadius = iconLabel.frame.width / 2
        iconBackgroundLabel.layer.masksToBounds = true
        contentView.layer.cornerRadius = 15
        
        self.contentView.backgroundColor = popupColor
        self.iconLabel.backgroundColor = .clear
        self.iconBackgroundLabel.backgroundColor = popupColor
        
        iconLabel.text = icon.asString
    }
    
    override func viewWillAppear(_ animated: Bool) {
        showAsAnimatedPopup()
        
        switch iconAnimation {
        case .rotate:
            animateIconRotation()
        case .zoomInZoomOut:
            animateIconZoomInZoomOut()
        case .swing:
            animateSwing()
        }
    }
    
    private func showAsAnimatedPopup() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        removeAsAnimatedPopup()
    }
    
    private func removeAsAnimatedPopup() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.view.alpha = 0.0;
            }, completion: { (finished : Bool) in
                if (finished) {
                    self.onClose?()
                }
        });
    }
    
    @IBAction func closeButtonPressed(_ sender: Any) {
        self.dismiss(animated: true) {
            self.closeButtonOnPressed?(true)
        }
    }
    
    @IBAction func optionalButtonPressed(_ sender: Any) {
        self.dismiss(animated: true) {
            self.optionalButtonOnPressed?(true)
        }
    }
    
    func setContent(topic: String, message: String, type: LogEntryType, customIcon: FontAwesomeIcon? = nil, customAnimation: PopupIconAnimation? = nil, onClosePressed: ((Bool) -> Void)? = nil) {
        self.topic = topic
        self.message = message
        self.logType = type
        self.closeButtonOnPressed = onClosePressed
        
        self.iconAnimation = customAnimation != nil ? customAnimation! : .zoomInZoomOut
        switch type {
        case .apiError:
            popupColor = .red
            self.icon = customIcon != nil ? customIcon! : .Exclamation
        case .error:
            popupColor = .red
            self.icon = customIcon != nil ? customIcon! : .Exclamation
        case .info:
            popupColor = .defaultBlue
            self.icon = customIcon != nil ? customIcon! : .Info
        case .debug:
            popupColor = .systemGray
            self.icon = customIcon != nil ? customIcon! : .Info
        }
    }
    
    func useOptionalButton(text: String, onPressed: ((Bool) -> Void)? = nil) {
        self.optionalButtonText = text
        self.optionalButtonOnPressed = onPressed
    }
    
    private func animateIconRotation() {
        UIView.animate(withDuration: 5, delay: 0, options: .repeat, animations: ({
            self.iconLabel.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }), completion: nil)
    }
    
    private func animateIconZoomInZoomOut() {
        UIView.animate(withDuration: 3, delay: 0, options: [], animations: ({
            self.iconLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }), completion: nil)
        UIView.animate(withDuration: 3, delay: 3, options: [.repeat, .autoreverse], animations: ({
            self.iconLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }), completion: nil)
    }
    
    private func animateSwing() {
        let rotationAngle = 0.18*CGFloat.pi
        UIView.animate(withDuration: 1.5, delay: 0, options: [], animations: ({
            self.iconLabel.transform = CGAffineTransform(rotationAngle: rotationAngle)
        }), completion: nil)
        UIView.animate(withDuration: 3, delay: 1.5, options: [.repeat, .autoreverse], animations: ({
            self.iconLabel.transform = CGAffineTransform(rotationAngle: -rotationAngle)
        }), completion: nil)
    }
    
}
