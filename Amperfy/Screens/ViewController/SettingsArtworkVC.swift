import Foundation
import UIKit

class SettingsArtworkVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var artworksCountLabel: UILabel!
    @IBOutlet weak var artworkNotCheckedCountLabel: UILabel!
    @IBOutlet weak var cachedArtworksCountLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)

        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)

            let artworkCount = library.artworkCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artworksCountLabel.text = String(artworkCount)
            }

            let artworkNotCheckedCount = library.artworkNotCheckedCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artworkNotCheckedCountLabel.text = String(artworkNotCheckedCount)
            }
            let cachedArtworkCount = library.cachedArtworkCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedArtworksCountLabel.text = String(cachedArtworkCount)
            }
        }
    }
    
    @IBAction func downloadAllArtworksInLibraryPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Download all artworks in library", message: "This action will add all uncached artworks to the download queue. With this action a lot network traffic can be generated and device storage capacity will be taken. Continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default , handler: { _ in
            let allArtworksToDownload = self.appDelegate.library.getArtworksForCompleteLibraryDownload()
            self.appDelegate.artworkDownloadManager.download(objects: allArtworksToDownload)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }

}
