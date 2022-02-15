import UIKit

class GenreTableCell: BasicTableCell {
    
    @IBOutlet weak var genreLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 38.0 + margin.bottom + margin.top
    
    private var genre: Genre?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(genre: Genre, rootView: UITableViewController) {
        self.genre = genre
        self.rootView = rootView
        genreLabel.text = genre.name
        infoLabel.text = genre.info(for: appDelegate.backendProxy.selectedApi, type: .short)
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let genre = genre, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: genre, on: rootView)
        rootView.present(detailVC, animated: true)
    }

}
