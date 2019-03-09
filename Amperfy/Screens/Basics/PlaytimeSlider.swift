import UIKit

class PlaytimeSlider: UISlider {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 4.0))
        super.trackRect(forBounds: customBounds)
        return customBounds
    }

}
