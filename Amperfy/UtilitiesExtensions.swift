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
import SwiftUI
import MarqueeLabel

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
        self.speed = .rate(30.0)
        if fadeLength != 10.0 {
            self.fadeLength = 10.0
        }
    }
}

extension Color {
    static let error = Color.red
    static let success = Color.green
    
    // MARK: - Text Colors
    static let lightText = Color(UIColor.lightText)
    static let darkText = Color(UIColor.darkText)
    static let placeholderText = Color(UIColor.placeholderText)

    // MARK: - Label Colors
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)

    // MARK: - Background Colors
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
    
    // MARK: - Fill Colors
    static let systemFill = Color(UIColor.systemFill)
    static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)
    
    // MARK: - Grouped Background Colors
    static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(UIColor.tertiarySystemGroupedBackground)
    
    // MARK: - Gray Colors
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray2 = Color(UIColor.systemGray2)
    static let systemGray3 = Color(UIColor.systemGray3)
    static let systemGray4 = Color(UIColor.systemGray4)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)
    
    // MARK: - Other Colors
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    static let link = Color(UIColor.link)
    
    // MARK: System Colors
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemPurple = Color(UIColor.systemPurple)
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemYellow = Color(UIColor.systemYellow)
    static let systemOrange = Color(UIColor.systemOrange)
    static let systemPink = Color(UIColor.systemPink)
    static let systemRed = Color(UIColor.systemRed)
    static let systemTeal = Color(UIColor.systemTeal)
    static let systemIndigo = Color(UIColor.systemIndigo)
}

extension Image {
    static let plus = Image(systemName: "plus")
    static let checkmark = Image(systemName: "checkmark")
}

public func withPopupAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try withAnimation(.easeInOut(duration: 0.2)) {
        try body()
    }
}

extension View {
    var appDelegate: AppDelegate {
        return (UIApplication.shared.delegate as! AppDelegate)
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
    
    public func setBackgroundBlur(style: UIBlurEffect.Style, alpha: CGFloat = 1.0) {
        self.backgroundColor = UIColor.clear
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = alpha
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.insertSubview(blurEffectView, at: 0)
    }

    public func updateBackgroundBlur(style: UIBlurEffect.Style, alpha: CGFloat = 1.0) {
        if let blurEffectView = self.subviews.first as? UIVisualEffectView {
            blurEffectView.removeFromSuperview()
        }
        setBackgroundBlur(style: style)
    }
}

extension UINavigationController {
    func replaceCurrentlyActiveVC(with vc: UIViewController, animated: Bool) {
        var vcs = self.viewControllers
        vcs = vcs.dropLast()
        vcs.append(vc)
        self.setViewControllers(vcs, animated:animated)
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
    
    func hasRowAt(indexPath: IndexPath) -> Bool {
        return indexPath.section < self.numberOfSections && indexPath.row < self.numberOfRows(inSection: indexPath.section)
    }
}

extension UICollectionView {
    func hasItemAt(indexPath: IndexPath) -> Bool {
        return indexPath.section < self.numberOfSections && indexPath.row < self.numberOfItems(inSection: indexPath.section)
    }
}

extension UITableViewController {
    func dequeueCell<CellType: UITableViewCell>(for tableView: UITableView, at indexPath: IndexPath) -> CellType {
        return self.tableView.dequeueCell(for: tableView, at: indexPath)
    }
    
    func refreshAllVisibleCells() {
        let visibleIndexPaths = tableView.visibleCells.compactMap{ tableView.indexPath(for: $0) }
        tableView.reconfigureRows(at: visibleIndexPaths)
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

extension NSObject {
    var appDelegate: AppDelegate {
        return (UIApplication.shared.delegate as! AppDelegate)
    }
}

extension UIApplication {
    var mainWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        for uiScene in scenes {
            if let windowScene = uiScene as? UIWindowScene {
                for window in windowScene.windows {
                    if window.isKeyWindow {
                        return window
                    }
                }
            }
        }
        return nil
    }
}

extension UITraitCollection {
    static let maxDisplayScale = UITraitCollection(displayScale: 3.0)
}

extension UITableViewCell {
    func animateActivation() {
        UIView.animate(withDuration: 0.2, animations: {
            self.markAsFocused()
        }, completion: { _ in
            self.markAsFocused()
            UIView.animate(withDuration: 0.2, animations: {
                self.markAsUnfocused()
            }, completion: { _ in
                self.markAsUnfocused()
            })
        })
    }
    
    func markAsFocused() {
        self.backgroundColor = .systemGray4
    }
    
    func markAsUnfocused() {
        self.backgroundColor = .clear
    }
}

extension UICollectionViewCell {
    func animateActivation() {
        UIView.animate(withDuration: 0.2, animations: {
            self.markAsFocused()
        }, completion: { _ in
            self.markAsFocused()
            UIView.animate(withDuration: 0.2, animations: {
                self.markAsUnfocused()
            }, completion: { _ in
                self.markAsUnfocused()
            })
        })
    }
    
    func markAsFocused() {
        let focuseBackground = UIView(frame: self.bounds)
        focuseBackground.backgroundColor = .systemGray4
        self.backgroundView = focuseBackground
    }
    
    func markAsUnfocused() {
        self.backgroundView = nil
    }
}

extension UIMenu {
    /// rebuilds menu on every access
    static func lazyMenu(title: String = "", builder: @escaping () -> UIMenu) -> UIMenu {
        #if targetEnvironment(macCatalyst)
        // https://forums.developer.apple.com/forums/thread/726665
        // UIDeferredMenuElement is completly broken in catalyst
        return UIMenu(title: title, children: [builder()])
        #else
        return UIMenu(title: title, children: [
                UIDeferredMenuElement.uncached { completion in
                    let menu = builder()
                    completion([menu])
                }
            ])
        #endif
    }
}

extension UIImage {
    func carPlayImage(carTraitCollection traits: UITraitCollection) -> UIImage {
        let imageAsset = UIImageAsset()
        imageAsset.register(self, with: traits)
        return imageAsset.image(with: traits)
    }
}

extension UIDevice.BatteryState {
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "@unknown default"
        }
    }
}

/// This fixes in swiftui mutliple picker views side by side to overlapp their touch areas
/// This is effective in addition to use .clipped() which only fixes the overlapping area visually
extension UIPickerView {
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric , height: 150)
    }
}
