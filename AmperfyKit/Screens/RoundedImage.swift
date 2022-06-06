import UIKit

public class RoundedImage: UIImageView {
    
    public static let cornerRadius: CGFloat = 5.0

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = Self.cornerRadius
        layer.masksToBounds = true
    }
    
}
