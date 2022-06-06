import UIKit
import AmperfyKit

class LogEntryTableCell: BasicTableCell {
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(entry: LogEntry) {
        messageLabel.text = entry.message
        var typeLabelText = "\(entry.type.description)"
        if entry.type == .error {
            typeLabelText += " \(CommonString.oneMiddleDot) Status code \(entry.statusCode)"
        }
        typeLabel.text = typeLabelText
        dateLabel.text = "\(entry.creationDate)"
    }

}
