import UIKit

class BasicTableCell: UITableViewCell {
    
    static let margin = UIView.defaultMarginCell
    
    let appDelegate: AppDelegate
    
    required init?(coder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: coder)
        self.layoutMargins = BasicTableCell.margin
    }
    
    override var layoutMargins: UIEdgeInsets { get { return BasicTableCell.margin } set { } }
    
    // MARK: - Hide cell under transparend table section
    
    public func maskCell(fromTop margin: CGFloat) {
        let gradientMask = visibilityMask(withLocation: margin / frame.size.height)
        layer.mask = gradientMask
        layer.masksToBounds = true
    }

    private func visibilityMask(withLocation location: CGFloat) -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.frame = bounds
        mask.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor]
        let num = location as NSNumber
        mask.locations = [num, num]
        return mask
    }
}
