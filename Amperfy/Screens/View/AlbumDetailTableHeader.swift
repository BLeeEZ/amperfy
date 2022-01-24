import UIKit

class AlbumDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var albumImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    private var album: Album?
    private var appDelegate: AppDelegate!
    private var rootView: AlbumDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnAlbum album: Album?, rootView: AlbumDetailVC? ) {
        guard let album = album else { return }
        self.album = album
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let album = album else { return }
        nameLabel.text = album.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        albumImage.displayAndUpdate(entity: album, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if album.songCount == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(album.songCount) Songs"
        }
        infoText += " \(CommonString.oneMiddleDot) \(album.duration.asDurationString)"
        if album.year != 0 {
            infoText += " \(CommonString.oneMiddleDot) Year \(album.year)"
        }
        infoLabel.text = infoText
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let album = album, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(album: album, on: rootView)
        rootView.present(detailVC, animated: true)
    }

}
