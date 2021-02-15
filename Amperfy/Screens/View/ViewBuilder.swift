import UIKit

class ViewBuilder<ViewType: UIView> {
    
    static func createFromNib() -> ViewType? {
        return UINib(
            nibName: ViewType.typeName,
            bundle: nil
            ).instantiate(withOwner: nil, options: nil)[0] as? ViewType
    }
    
    static func createFromNib(withinFixedFrame rect: CGRect) -> ViewType? {
        guard let nibView: ViewType = createFromNib() else {
            return nil
        }
        nibView.frame = rect
        return nibView
    }
    
}
