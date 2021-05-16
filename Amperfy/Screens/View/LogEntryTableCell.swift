import UIKit

class LogEntryTableCell: BasicTableCell {
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(entry: LogEntry) {
        messageLabel.text = entry.message
        typeLabel.text = "Error \(CommonString.oneMiddleDot) Status code \(entry.statusCode)"
        dateLabel.text = "\(entry.creationDate)"
    }

}
