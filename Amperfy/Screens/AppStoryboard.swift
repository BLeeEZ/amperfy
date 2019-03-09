import Foundation
import UIKit

enum AppStoryboard : String {
    
    case Main = "Main"

    var instance : UIStoryboard {
        return UIStoryboard(name: self.rawValue, bundle: Bundle.main)
    }
    
    func viewController<T: UIViewController>(viewControllerClass: T.Type) -> T {
        return self.instance.instantiateViewController(withIdentifier: viewControllerClass.storyboardID) as! T
    }
    
}

extension UIViewController {
    
    class var storyboardID : String {
        return "\(self)"
    }
    
    static func instantiateFromAppStoryboard(appStoryboard: AppStoryboard = .Main) -> Self {
        return appStoryboard.viewController(viewControllerClass: self)
    }
    
}
