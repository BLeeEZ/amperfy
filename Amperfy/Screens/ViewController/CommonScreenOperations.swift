import Foundation
import UIKit

enum SongOperationDisplayModes {
    case libraryCell
    case playerCell
}

extension UIView {
    static let defaultMarginX: CGFloat = 16
    static let defaultMarginY: CGFloat = 11
    static let defaultMarginTopElement = UIEdgeInsets(top: UIView.defaultMarginY, left: UIView.defaultMarginX, bottom: 0.0, right: UIView.defaultMarginX)
    static let defaultMarginMiddleElement = UIEdgeInsets(top: UIView.defaultMarginY, left: UIView.defaultMarginX, bottom: UIView.defaultMarginY, right: UIView.defaultMarginX)
    static let defaultMarginCellX: CGFloat = 16
    static let defaultMarginCellY: CGFloat = 9
    static let defaultMarginCell = UIEdgeInsets(top: UIView.defaultMarginCellY, left: UIView.defaultMarginCellX, bottom: UIView.defaultMarginCellY, right: UIView.defaultMarginCellX)
}

class CommonScreenOperations {
    
    static let tableSectionHeightLarge: CGFloat = 40
    
}
