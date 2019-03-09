import UIKit

class ViewBuilder<ViewType: UIView> {
    
    static func createFromNib() -> ViewType? {
        return UINib(
            nibName: ViewType.typeName,
            bundle: nil
            ).instantiate(withOwner: nil, options: nil)[0] as? ViewType
    }
    
    static func createFromNib(withinFixedFrame rect: CGRect) -> (fixedView: UIView, customView: ViewType)? {
        guard let nibView: ViewType = createFromNib() else {
            return nil
        }
        
        let fixedView = UIView(frame: rect)
        fixedView.addSubview(nibView)
        return (fixedView, nibView)
    }
    
}
