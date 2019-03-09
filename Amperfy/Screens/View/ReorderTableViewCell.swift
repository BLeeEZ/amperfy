import UIKit

class ReorderTableViewCell: UITableViewCell {
    
    override var showsReorderControl: Bool {
        get {
            return true
        }
        set { }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        if editing == false {
            return // ignore any attempts to turn it off
        }
        super.setEditing(editing, animated: animated)
    }
}
