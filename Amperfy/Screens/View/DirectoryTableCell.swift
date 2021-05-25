import UIKit

class DirectoryTableCell: BasicTableCell {
    
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top
    
    func display(folder: MusicFolder) {
        infoLabel.text = folder.name
    }
    
    func display(directory: MusicDirectory) {
        infoLabel.text = directory.name
    }

}
