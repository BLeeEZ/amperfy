import Foundation
import UIKit

class AboutVC: UIViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var aboutTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        aboutTextView.text = """
        All attributions can also be found here:
        https://github.com/BLeeEZ/amperfy
        
        Amperfy is licensed under GPLv3 License:
        https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE
        
        LNPopupController by LeoNatan is licensed under MIT License:
        https://github.com/LeoNatan/LNPopupController
        https://github.com/LeoNatan
        https://github.com/LeoNatan/LNPopupController/blob/master/LICENSE
        
        MarqueeLabel by Charles Powell is licensed under MIT License:
        https://github.com/cbpowell/MarqueeLabel
        https://github.com/cbpowell
        https://github.com/cbpowell/MarqueeLabel/blob/master/LICENSE
        
        Font Awesome Icons by Font Awesome is licensed under CC BY 4.0 License:
        https://fontawesome.com
        https://creativecommons.org/licenses/by/4.0
        
        Font Awesome Fonts by Font Awesome is licensed under SIL OFL 1.1 License:
        https://fontawesome.com
        https://scripts.sil.org/OFL
        
        iOS 11 Glyphs by Icons8 is licensed under Good Boy License
        https://icons8.com/ios
        https://icons8.com
        https://icons8.com/good-boy-license
        """
    }
    
}
