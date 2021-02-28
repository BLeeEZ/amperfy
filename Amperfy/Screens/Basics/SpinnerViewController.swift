import Foundation
import UIKit

class SpinnerViewController: UIViewController {
    var spinner = UIActivityIndicatorView(style: .whiteLarge)

    override func loadView() {
        view = UIView()

        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.quaternarySystemFill
            spinner.color = UIColor.placeholderText
        } else {
            view.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        }

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        NSLayoutConstraint(item: view!,
                           attribute: .centerY,
                           relatedBy: .equal,
                           toItem: spinner,
                           attribute: .centerY,
                           multiplier: 1.0,
                           constant: 200).isActive = true
    }
    
    func display(on hostVC: UIViewController) {
        hostVC.addChild(self)
        self.view.frame = hostVC.view.frame
        hostVC.view.addSubview(self.view)
        self.didMove(toParent: hostVC)
    }
    
    func hide() {
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }
}
