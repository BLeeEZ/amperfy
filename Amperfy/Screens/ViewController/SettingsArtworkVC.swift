import Foundation
import UIKit
import AmperfyKit

class SettingsArtworkVC: UITableViewController {
    
    static let artworkNotCheckedThreshold = 10
    
    var appDelegate: AppDelegate!
    var timer: Timer?
    
    @IBOutlet weak var artworkNotCheckedCountLabel: UILabel!
    @IBOutlet weak var cachedArtworksCountLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        updateValues()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateValues), userInfo: nil, repeats: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func updateValues() {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)

            let artworkNotCheckedCount = library.artworkNotCheckedCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let artworkNotCheckedDisplayCount = artworkNotCheckedCount > Self.artworkNotCheckedThreshold ? artworkNotCheckedCount : 0
                self.artworkNotCheckedCountLabel.text = String(artworkNotCheckedDisplayCount)
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
