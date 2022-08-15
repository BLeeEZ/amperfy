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
