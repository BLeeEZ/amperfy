//
//  UtilitiesExtensions.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.06.22.
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

import Foundation
import UIKit
import os.log
import AmperfyKit

extension MarqueeLabel {
    func applyAmperfyStyle() {
        if trailingBuffer != 30.0 {
            self.trailingBuffer = 30.0
        }
        if leadingBuffer != 0.0 {
            self.leadingBuffer = 0.0
        }
        if animationDelay != 2.0 {
            self.animationDelay = 2.0
        }
        if type != .continuous {
            self.type = .continuous
        }
        if speed.value != 30.0 {
            self.speed = .rate(30.0)
        }
        if fadeLength != 10.0 {
            self.fadeLength = 10.0
        }
    }
}

extension UIView {
    static let forceTouchClickLimit: Float = 1.0

    func normalizedForce(touches: Set<UITouch>) -> Float? {
        guard is3DTouchAvailable, let touch = touches.first else { return nil }
        let maximumForce = touch.maximumPossibleForce
        let force = touch.force
        let normalizedForce = (force / maximumForce)
        return Float(normalizedForce)
    }
    
    func isForceClicked(_ touches: Set<UITouch>) -> Bool {
        guard let force = normalizedForce(touches: touches) else { return false }
        if force < UIView.forceTouchClickLimit {
            return false
        } else {
            return true
        }
    }
    
    var is3DTouchAvailable: Bool {
        return  forceTouchCapability() == .available
    }
    
    func forceTouchCapability() -> UIForceTouchCapability {
        return UIApplication.shared.mainWindow?.rootViewController?.traitCollection.forceTouchCapability ?? .unknown
    }
    
    public func setBackgroundBlur(style: UIBlurEffect.Style, backupBackgroundColor: UIColor = .backgroundColor) {
        if #available(iOS 13.0, *) {
            self.backgroundColor = UIColor.clear
            let blurEffect = UIBlurEffect(style: .prominent)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = self.frame
            self.insertSubview(blurEffectView, at: 0)
        } else {
            self.backgroundColor = backupBackgroundColor
        }
    }
}

extension UITableView {
    func register(nibName: String) {
        self.register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: nibName)
    }
    
    func dequeueCell<CellType: UITableViewCell>(for tableView: UITableView, at indexPath: IndexPath) -> CellType {
        guard let cell = self.dequeueReusableCell(withIdentifier: CellType.typeName, for: indexPath) as? CellType else {
            os_log(.error, "The dequeued cell is not an instance of %s", CellType.typeName)
            return CellType()
        }
        return cell
    }
}

extension UITableViewController {
    func dequeueCell<CellType: UITableViewCell>(for tableView: UITableView, at indexPath: IndexPath) -> CellType {
        return self.tableView.dequeueCell(for: tableView, at: indexPath)
    }
    
    func refreshAllVisibleCells() {
        let visibleIndexPaths = tableView.visibleCells.compactMap{ tableView.indexPath(for: $0) }
        tableView.reloadRows(at: visibleIndexPaths, with: .none)
    }
    
    func exectueAfterAnimation(body: @escaping () -> Void) {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                body()
            }
        }
    }
}

extension UIViewController {
    var typeName: String {
        return Self.typeName
    }
}

extension UIApplication {
    var mainWindow: UIWindow? {
        return windows.first(where: \.isKeyWindow)
    }
}

extension UIImage {
    private static func createEmptyImage(with size: CGSize) -> UIImage?
    {
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    static func numberToImage(number: Int) -> UIImage {
        let fontSize = 40.0
        let textFont = UIFont(name: "Helvetica Bold", size: fontSize)!

        let image = createEmptyImage(with: CGSize(width: 100.0, height: 100.0)) ?? UIImage()
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(image.size, false, scale)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.foregroundColor: UIColor.lightGray,
        ] as [NSAttributedString.Key : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

        let textPoint = CGPoint(x: 0.0, y: 50.0-(fontSize/2))
        let rect = CGRect(origin: textPoint, size: image.size)
        number.description.draw(in: rect, withAttributes: textFontAttributes)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}
