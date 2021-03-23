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

}
