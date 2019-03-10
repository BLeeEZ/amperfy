import Foundation
import UIKit

class OptionsBarButtonItem: UIBarButtonItem {
    
    init(target: AnyObject?, action: Selector?) {
        super.init()
        
        let fontSize:CGFloat = 25
        let font:UIFont = UIFont.boldSystemFont(ofSize: fontSize)
        let attributes:[NSAttributedString.Key : Any] = [NSAttributedString.Key.font: font]

        self.title = CommonString.threeMiddleDots
        self.style = .plain
        self.target = target
        self.action = action
        self.setTitleTextAttributes(attributes, for: UIControl.State.normal)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
